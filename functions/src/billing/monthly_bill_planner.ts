import {
  BillingTerm, BillingPause, DeliveryException, Newspaper,
  isDateIncluded, includesWeekday
} from "./billing_types";

export interface MonthlyBillLineItem {
  chargeKey: string;
  serviceDate: string;
  subscriptionId: string;
  versionId: string;
  newspaperId: string;
  newspaperName: string;
  unitPricePaise: number;
  quantity: number;
  priceSource: 'defaultPrice' | 'effectivePeriod' | 'exactDate' | 'customerSpecific';
  priceSourceId: string;
  priceRuleRevision: number;
  totalPaise: number;
}

export class MonthlyBillPlanner {
  
  static getDaysInMonth(year: number, month: number): number {
    return new Date(Date.UTC(year, month, 0)).getUTCDate();
  }

  static pad(n: number): string {
    return n < 10 ? '0' + n : '' + n;
  }

  static calculate(
    customerId: string,
    billingMonth: string, // YYYY-MM
    terms: BillingTerm[],
    pauses: BillingPause[],
    deliveryExceptions: DeliveryException[],
    newspapers: Record<string, Newspaper>
  ): MonthlyBillLineItem[] {
    const [yearStr, monthStr] = billingMonth.split('-');
    const year = parseInt(yearStr, 10);
    const month = parseInt(monthStr, 10);
    const daysInMonth = this.getDaysInMonth(year, month);
    
    this.validateTermTimelines(terms);
    const seen = new Set<string>();
    const lines: MonthlyBillLineItem[] = [];
    const noDelivery = new Set(
      deliveryExceptions.map(e => `${e.subscriptionId}:${e.serviceDate}`)
    );

    for (const term of terms) {
      const paper = newspapers[term.newspaperId];
      if (!paper) {
        throw new Error(`Missing newspaper ${term.newspaperId} for subscription ${term.subscriptionId}.`);
      }
      if (paper.name.trim().length < 2 || paper.defaultPricePaise < 0 || paper.defaultPricePaise > 1000000) {
        throw new Error(`Missing or invalid default price for ${paper.name}.`);
      }

      const monthLastDayStr = `${yearStr}-${monthStr}-${this.pad(daysInMonth)}`;
      const monthFirstDayStr = `${yearStr}-${monthStr}-01`;

      const monthlyRules = paper.rules.filter(rule => 
        !rule.isExactDate &&
        rule.pricingBasis === 'monthly' &&
        !(rule.startDate > monthLastDayStr) &&
        !(rule.endDate < monthFirstDayStr)
      );

      if (monthlyRules.length > 0) {
        const monthlyRule = monthlyRules[0];
        const activeDates: string[] = [];
        for (let day = 1; day <= daysInMonth; day++) {
          const dateStr = `${yearStr}-${monthStr}-${this.pad(day)}`;
          if (!isDateIncluded(dateStr, term.effectiveFrom, term.effectiveTo)) continue;
          if (!includesWeekday(dateStr, term.deliveryWeekdays)) continue;
          
          if (pauses.some(p => p.subscriptionId === term.subscriptionId && isDateIncluded(dateStr, p.startDate, p.endDate))) {
            continue;
          }
          if (noDelivery.has(`${term.subscriptionId}:${dateStr}`)) continue;
          activeDates.push(dateStr);
        }
        
        if (activeDates.length > 0) {
          const key = `${customerId}:${term.subscriptionId}:${billingMonth}`;
          if (seen.has(key)) {
            throw new Error(`Overlapping subscription versions would duplicate ${billingMonth} for ${paper.name}.`);
          }
          seen.add(key);
          const hasCustomerOverride = term.customPricePaise !== null;
          const unitPrice = hasCustomerOverride ? term.customPricePaise! : monthlyRule.pricePaise;
          lines.push({
            chargeKey: key,
            serviceDate: activeDates[0],
            subscriptionId: term.subscriptionId,
            versionId: term.versionId,
            newspaperId: term.newspaperId,
            newspaperName: paper.name,
            unitPricePaise: unitPrice,
            quantity: term.quantity,
            priceSource: hasCustomerOverride ? 'customerSpecific' : 'effectivePeriod',
            priceSourceId: hasCustomerOverride ? term.subscriptionId : monthlyRule.ruleId,
            priceRuleRevision: hasCustomerOverride ? 0 : monthlyRule.revision,
            totalPaise: unitPrice * term.quantity
          });
        }
        continue;
      }

      for (let day = 1; day <= daysInMonth; day++) {
        const dateStr = `${yearStr}-${monthStr}-${this.pad(day)}`;
        if (!isDateIncluded(dateStr, term.effectiveFrom, term.effectiveTo)) continue;
        if (!includesWeekday(dateStr, term.deliveryWeekdays)) continue;
        
        if (pauses.some(p => p.subscriptionId === term.subscriptionId && isDateIncluded(dateStr, p.startDate, p.endDate))) {
          continue;
        }
        if (noDelivery.has(`${term.subscriptionId}:${dateStr}`)) continue;
        
        const key = `${customerId}:${term.subscriptionId}:${dateStr}`;
        if (seen.has(key)) {
          throw new Error(`Overlapping subscription versions would duplicate ${dateStr} for ${paper.name}.`);
        }
        seen.add(key);
        
        const price = this.resolvePrice(term, paper, dateStr);
        lines.push({
          chargeKey: key,
          serviceDate: dateStr,
          subscriptionId: term.subscriptionId,
          versionId: term.versionId,
          newspaperId: term.newspaperId,
          newspaperName: paper.name,
          unitPricePaise: price.unitPrice,
          quantity: term.quantity,
          priceSource: price.source,
          priceSourceId: price.sourceId,
          priceRuleRevision: price.revision,
          totalPaise: price.unitPrice * term.quantity
        });
      }
    }

    lines.sort((left, right) => {
      const byDate = left.serviceDate.localeCompare(right.serviceDate);
      return byDate !== 0 ? byDate : left.subscriptionId.localeCompare(right.subscriptionId);
    });

    if (lines.length > 500) {
      throw new Error('This bill has too many daily lines for one safe atomic finalization.');
    }

    return lines;
  }

  static validateTermTimelines(terms: BillingTerm[]) {
    // simplified overlapping check for TS side
    const grouped = new Map<string, BillingTerm[]>();
    for (const term of terms) {
      if (!grouped.has(term.subscriptionId)) grouped.set(term.subscriptionId, []);
      grouped.get(term.subscriptionId)!.push(term);
    }
    for (const [subId, timeline] of grouped.entries()) {
      timeline.sort((a, b) => a.effectiveFrom.localeCompare(b.effectiveFrom));
      for (let i = 1; i < timeline.length; i++) {
        const prevEnd = timeline[i-1].effectiveTo;
        if (!prevEnd || prevEnd >= timeline[i].effectiveFrom) {
          throw new Error(`Overlapping subscription versions exist for ${subId}.`);
        }
      }
    }
  }

  static resolvePrice(term: BillingTerm, paper: Newspaper, dateStr: string) {
    if (term.customPricePaise !== null) {
      return { unitPrice: term.customPricePaise, source: 'customerSpecific' as const, sourceId: term.versionId, revision: 0 };
    }
    const matching = paper.rules.filter(rule => isDateIncluded(dateStr, rule.startDate, rule.endDate));
    const exact = matching.filter(r => r.isExactDate);
    const periods = matching.filter(r => !r.isExactDate);
    if (exact.length > 1 || periods.length > 1) {
      throw new Error(`Ambiguous active pricing for ${paper.name} on ${dateStr}.`);
    }
    if (exact.length > 0) {
      return { unitPrice: exact[0].pricePaise, source: 'exactDate' as const, sourceId: exact[0].ruleId, revision: exact[0].revision };
    }
    if (periods.length > 0) {
      return { unitPrice: periods[0].pricePaise, source: 'effectivePeriod' as const, sourceId: periods[0].ruleId, revision: periods[0].revision };
    }
    return { unitPrice: paper.defaultPricePaise, source: 'defaultPrice' as const, sourceId: paper.newspaperId, revision: 0 };
  }
}
