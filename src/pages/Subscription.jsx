import { Paywall } from '../components/PremiumGate';

// Always-visible "My Subscription" page — status + upgrade form, whether
// the caller is free, on a trial, or already Premium. Distinct from
// /subscriptions (recurring-bill tracking, unrelated feature).
export default function Subscription() {
  return (
    <div className="animate-in">
      <Paywall module="subscription" labelOverride="Premium" />
    </div>
  );
}
