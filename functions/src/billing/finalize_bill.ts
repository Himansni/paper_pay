import * as functions from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { MonthlyBillPlanner, MonthlyBillLineItem } from "./monthly_bill_planner";
import { BillingTerm, BillingPause, DeliveryException, Newspaper, PriceRule } from "./billing_types";

function getDaysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function pad(n: number): string {
  return n < 10 ? '0' + n : '' + n;
}

export const finalizeMonthlyBill = functions.onCall({
  region: "asia-south1",
  enforceAppCheck: false,
}, async (request) => {
  const data = request.data;
  const { businessId, customerId, billingMonth, adjustmentRevision, collectionStateRevision, clientTotalDuePaise, billingSource, manualPreview } = data;
  const uid = request.auth?.uid;

  if (!uid) throw new functions.HttpsError('unauthenticated', 'User must be signed in.');
  if (!businessId || !customerId || !billingMonth) {
    throw new functions.HttpsError('invalid-argument', 'Missing parameters.');
  }

  const db = getFirestore();
  
  // Authorization
  const memberDoc = await db.collection(`businesses/${businessId}/members`).doc(uid).get();
  if (!memberDoc.exists) throw new functions.HttpsError('permission-denied', 'Unauthorized.');
  const member = memberDoc.data()!;
  if (member.status !== 'active') throw new functions.HttpsError('permission-denied', 'Unauthorized.');
  
  const isHead = member.role === 'head';
  const hasManualBilling = member.permissions?.includes('allowManualBilling');
  
  const customerRef = db.collection(`businesses/${businessId}/customers`).doc(customerId);
  const customerDoc = await customerRef.get();
  if (!customerDoc.exists) throw new functions.HttpsError('not-found', 'Customer not found.');
  const customer = customerDoc.data()!;
  
  if (!isHead && (!hasManualBilling || customer.assignedEmployeeId !== uid || !member.areaIds?.includes(customer.areaId))) {
    throw new functions.HttpsError('permission-denied', 'Only authorized employees can finalize bills.');
  }
  if (customer.status !== 'active') {
    throw new functions.HttpsError('failed-precondition', 'Customer is not active.');
  }

  const [yearStr, monthStr] = billingMonth.split('-');
  const monthEndStr = `${yearStr}-${monthStr}-${pad(getDaysInMonth(parseInt(yearStr, 10), parseInt(monthStr, 10)))}`;
  const monthStartStr = `${yearStr}-${monthStr}-01`;

  return db.runTransaction(async (transaction: FirebaseFirestore.Transaction) => {
    // 1. Check if already finalized
    const billRef = customerRef.collection('bills').doc(billingMonth);
    const existingBillDoc = await transaction.get(billRef);
    if (existingBillDoc.exists && existingBillDoc.data()?.status === 'finalized') {
      return { success: true, billId: billingMonth, alreadyFinalized: true };
    }

    const controlRef = customerRef.collection('billingControls').doc(billingMonth);
    const controlDoc = await transaction.get(controlRef);
    const controlData = controlDoc.data();
    if ((controlData?.adjustmentRevision ?? 0) !== (adjustmentRevision ?? 0) || (controlData?.status && controlData?.status !== 'open')) {
      throw new functions.HttpsError('failed-precondition', 'Billing adjustments changed or not open.');
    }

    // 2. Fetch dependencies
    const subsSnap = await transaction.get(customerRef.collection('subscriptions'));
    const exceptionsSnap = await transaction.get(customerRef.collection('deliveryExceptions')
      .where('serviceDate', '>=', monthStartStr)
      .where('serviceDate', '<=', monthEndStr));
    const adjustmentsSnap = await transaction.get(customerRef.collection('adjustments')
      .where('billingMonth', '==', billingMonth));
    const collectionStateRef = customerRef.collection('collectionState').doc('current');
    const collectionStateDoc = await transaction.get(collectionStateRef);
    
    if (collectionStateDoc.exists) {
      if ((collectionStateDoc.data()?.revision ?? 0) !== (collectionStateRevision ?? 0)) {
        throw new functions.HttpsError('failed-precondition', 'Customer outstanding balance changed.');
      }
    }

    const terms: BillingTerm[] = [];
    const pauses: BillingPause[] = [];
    const newspaperIds = new Set<string>();

    for (const sub of subsSnap.docs) {
      const versionsSnap = await transaction.get(sub.ref.collection('versions'));
      for (const v of versionsSnap.docs) {
        const vData = v.data();
        if (vData.effectiveFrom > monthEndStr || (vData.effectiveTo && vData.effectiveTo < monthStartStr)) continue;
        terms.push({
          subscriptionId: sub.id,
          versionId: v.id,
          newspaperId: vData.newspaperId,
          quantity: vData.quantity ?? 0,
          deliveryWeekdays: vData.deliveryWeekdays ?? [],
          customPricePaise: vData.customPricePaise ?? null,
          effectiveFrom: vData.effectiveFrom,
          effectiveTo: vData.effectiveTo ?? null,
        });
        newspaperIds.add(vData.newspaperId);
      }
      const pausesSnap = await transaction.get(sub.ref.collection('pauses'));
      for (const p of pausesSnap.docs) {
        const pData = p.data();
        if (pData.startDate > monthEndStr || (pData.endDate && pData.endDate < monthStartStr)) continue;
        pauses.push({
          subscriptionId: sub.id,
          startDate: pData.startDate,
          endDate: pData.endDate ?? null,
        });
      }
    }

    const deliveryExceptions: DeliveryException[] = exceptionsSnap.docs.map((d: any) => ({
      subscriptionId: d.data().subscriptionId,
      serviceDate: d.data().serviceDate
    }));

    const newspapers: Record<string, Newspaper> = {};
    for (const nid of Array.from(newspaperIds)) {
      const npDoc = await transaction.get(db.collection(`businesses/${businessId}/newspapers`).doc(nid));
      if (!npDoc.exists) continue;
      const npData = npDoc.data()!;
      const rulesSnap = await transaction.get(npDoc.ref.collection('priceRules'));
      const rules = rulesSnap.docs.map((r: any) => ({
        ruleId: r.id,
        revision: r.data().revision ?? 1,
        startDate: r.data().startDate,
        endDate: r.data().endDate,
        isExactDate: r.data().isExactDate ?? false,
        pricingBasis: r.data().pricingBasis ?? 'daily',
        pricePaise: r.data().pricePaise ?? 0
      }));
      newspapers[nid] = {
        newspaperId: nid,
        name: npData.name,
        defaultPricePaise: npData.defaultPricePaise ?? 0,
        rules
      };
    }

    let lineItems: MonthlyBillLineItem[] = [];
    let currentChargesPaise = 0;
    let newspaperSummaries: Record<string, any> = {};

    if (billingSource === 'manual' && manualPreview) {
      if (!hasManualBilling && !isHead) {
        throw new functions.HttpsError('permission-denied', 'Only authorized employees can finalize manual bills.');
      }
      lineItems = manualPreview.lineItems || [];
      currentChargesPaise = manualPreview.currentChargesPaise || 0;
      for (const summary of (manualPreview.newspaperSummaries || [])) {
        newspaperSummaries[summary.newspaperId] = summary;
      }
    } else {
      lineItems = MonthlyBillPlanner.calculate(customerId, billingMonth, terms, pauses, deliveryExceptions, newspapers);
      for (const item of lineItems) {
        currentChargesPaise += item.totalPaise;
        if (!newspaperSummaries[item.newspaperId]) {
          newspaperSummaries[item.newspaperId] = {
            newspaperId: item.newspaperId,
            newspaperName: item.newspaperName,
            totalAmountPaise: 0
          };
        }
        newspaperSummaries[item.newspaperId].totalAmountPaise += item.totalPaise;
      }
    }

    let adjustmentsPaise = 0;
    for (const a of adjustmentsSnap.docs) {
      adjustmentsPaise += (a.data().amountPaise ?? 0);
    }

    let priorBalancePaise = collectionStateDoc.exists ? (collectionStateDoc.data()?.outstandingPaise ?? 0) : customer.openingBalancePaise ?? 0;
    const totalDuePaise = priorBalancePaise + currentChargesPaise + adjustmentsPaise;

    if (clientTotalDuePaise !== undefined && totalDuePaise !== clientTotalDuePaise) {
      throw new functions.HttpsError('failed-precondition', `Server total (${totalDuePaise}) does not match client total (${clientTotalDuePaise}).`);
    }

    // 4. Write transaction
    const now = FieldValue.serverTimestamp();
    const auditRef = db.collection(`businesses/${businessId}/auditRecords`).doc();

    transaction.set(billRef, {
      businessId, customerId, 
      customerCode: customer.customerCode ?? customerId,
      customerName: customer.name,
      customerSearchName: customer.name.toLowerCase(),
      customerAddress: customer.address ?? '',
      areaId: customer.areaId,
      assignedEmployeeId: customer.assignedEmployeeId,
      customerStatus: customer.status,
      billingMonth,
      billingSource: billingSource === 'manual' ? 'manual' : 'generated',
      status: 'finalized',
      openingBalancePaise: customer.openingBalancePaise ?? 0,
      previousBillId: '', // Skipping exact resolution of previous bill for now
      previousOutstandingPaise: 0,
      priorBalancePaise,
      currentChargesPaise,
      adjustmentsPaise,
      totalDuePaise,
      lineItemCount: lineItems.length,
      newspaperSummaries: Object.values(newspaperSummaries),
      calculationVersion: 'paper-route-monthly-v2-server',
      finalizedBy: uid,
      createdBy: uid,
      lastAuditId: auditRef.id,
      finalizedAt: now,
      createdAt: now,
    });

    for (const line of lineItems) {
      transaction.set(billRef.collection('lineItems').doc(line.chargeKey), {
        businessId, customerId,
        billId: billingMonth,
        billingMonth,
        chargeKey: line.chargeKey,
        serviceDate: line.serviceDate,
        subscriptionId: line.subscriptionId,
        versionId: line.versionId,
        newspaperId: line.newspaperId,
        newspaperName: line.newspaperName,
        unitPricePaise: line.unitPricePaise,
        quantity: line.quantity,
        totalPaise: line.totalPaise,
        priceSource: line.priceSource,
        priceSourceId: line.priceSourceId,
        priceRuleRevision: line.priceRuleRevision,
        lastAuditId: auditRef.id,
        createdAt: now,
      });
    }

    const nextControl = {
      businessId, customerId, billingMonth,
      status: 'finalized',
      adjustmentRevision: controlData?.adjustmentRevision ?? 0,
      finalizedBillId: billingMonth,
      updatedBy: uid,
      lastAuditId: auditRef.id,
      updatedAt: now,
    };
    if (controlDoc.exists) transaction.update(controlRef, nextControl);
    else transaction.set(controlRef, { ...nextControl, createdAt: now });

    const componentAmountPaise = collectionStateDoc.exists ? (currentChargesPaise + adjustmentsPaise) : totalDuePaise;
    const componentOutstandingPaise = componentAmountPaise > 0 ? componentAmountPaise : 0;
    
    transaction.set(customerRef.collection('billBalances').doc(billingMonth), {
      businessId, customerId,
      billId: billingMonth,
      billingMonth,
      sourceAmountPaise: componentAmountPaise,
      allocatedPaise: 0,
      reversedPaise: 0,
      outstandingPaise: componentOutstandingPaise,
      status: componentAmountPaise > 0 ? 'outstanding' : (componentAmountPaise < 0 ? 'credit' : 'settled'),
      revision: 0,
      lastMutationType: 'billFinalized',
      lastMutationId: billingMonth,
      createdAt: now,
      updatedAt: now,
    });

    const confirmedPaise = collectionStateDoc.data()?.confirmedPaise ?? 0;
    const reversedPaise = collectionStateDoc.data()?.reversedPaise ?? 0;
    const reportingStatus = totalDuePaise <= 0 ? (totalDuePaise < 0 ? 'credit' : 'fullyPaid') : 
      (confirmedPaise > reversedPaise ? 'partiallyPaid' : 'unpaid');
    let oldestOutstandingMonth = billingMonth;
    if (totalDuePaise > 0) {
      const currentOldest = collectionStateDoc.data()?.oldestOutstandingMonth;
      if (currentOldest && currentOldest < billingMonth) {
        oldestOutstandingMonth = currentOldest;
      }
    } else {
      oldestOutstandingMonth = '';
    }

    const nextCollectionState = {
      businessId, customerId, stateId: 'current',
      customerCode: customer.customerCode ?? customerId,
      customerName: customer.name,
      areaId: customer.areaId,
      assignedEmployeeId: customer.assignedEmployeeId,
      customerStatus: customer.status,
      outstandingPaise: totalDuePaise,
      confirmedPaise, reversedPaise, reportingStatus,
      oldestOutstandingMonth: oldestOutstandingMonth || billingMonth,
      revision: (collectionStateDoc.data()?.revision ?? 0) + 1,
      lastMutationType: 'billFinalized',
      lastMutationId: billingMonth,
      updatedBy: uid,
      updatedAt: now,
    };
    if (collectionStateDoc.exists) transaction.update(collectionStateRef, nextCollectionState);
    else transaction.set(collectionStateRef, { ...nextCollectionState, createdAt: now });

    transaction.set(auditRef, {
      businessId, actorId: uid, actorRole: member.role,
      action: 'billFinalized', entityType: 'bill', entityId: `${customerId}:${billingMonth}`,
      customerId, billingMonth, lineItemCount: lineItems.length,
      currentChargesPaise, priorBalancePaise, adjustmentsPaise, totalDuePaise,
      controlRevision: controlData?.adjustmentRevision ?? 0,
      createdAt: now,
    });

    return { success: true, billId: billingMonth };
  });
});
