import * as admin from "firebase-admin";

export interface BillingTerm {
  subscriptionId: string;
  versionId: string;
  newspaperId: string;
  quantity: number;
  deliveryWeekdays: number[];
  customPricePaise: number | null;
  effectiveFrom: string; // YYYY-MM-DD
  effectiveTo: string | null;
}

export interface BillingPause {
  subscriptionId: string;
  startDate: string;
  endDate: string | null;
}

export interface DeliveryException {
  subscriptionId: string;
  serviceDate: string;
}

export interface PriceRule {
  ruleId: string;
  revision: number;
  startDate: string;
  endDate: string;
  isExactDate: boolean;
  pricingBasis: 'monthly' | 'daily';
  pricePaise: number;
}

export interface Newspaper {
  newspaperId: string;
  name: string;
  defaultPricePaise: number;
  rules: PriceRule[];
}

export function isDateIncluded(dateStr: string, fromStr: string, toStr: string | null): boolean {
  if (dateStr < fromStr) return false;
  if (toStr && dateStr > toStr) return false;
  return true;
}

export function includesWeekday(dateStr: string, weekdays: number[]): boolean {
  const d = new Date(dateStr + "T12:00:00Z");
  const day = d.getUTCDay(); // 0 is Sunday, 1 is Monday ... 6 is Saturday
  const dartDay = day === 0 ? 7 : day;
  return weekdays.includes(dartDay);
}
