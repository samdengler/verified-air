package offerorder;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Optional;
import java.util.function.Consumer;
import net.jqwik.api.Arbitrary;
import net.jqwik.api.ForAll;
import net.jqwik.api.Label;
import net.jqwik.api.Property;
import net.jqwik.api.Provide;
import net.jqwik.api.Tag;
import net.jqwik.api.lifecycle.PropertyExecutionResult;
import net.jqwik.testing.ExpectFailure;

/**
 * Option 2, the model's theorems as properties of the Java code.  Each
 * property restates one Lean theorem and is tagged with the acceptance
 * criterion it checks, so {@code mvn test -Dgroups=OO-001.1} runs just that one.
 *
 * <p>A passing property is evidence for the inputs jqwik tried, not a proof.
 * The open theorem shows the other side: jqwik finds the counterexample on its
 * own and shrinks it to two refunds against one payment.
 */
@Label("Java satisfies the model's guarantees")
class GuaranteeProperties {

  @Property(tries = 2000)
  @Tag("OO-001.1")
  @Label("accept_rejects_expired: an offer accepted at or after expiry is rejected as expired")
  void acceptRejectsExpired(@ForAll("offers") Offer offer, @ForAll("instants") long now) {
    if (now >= offer.expiresAt()) {
      assertEquals(new AcceptResult.Rejected(Rejection.EXPIRED), OfferOrderRules.accept(offer, now, "ORD-1"));
    }
  }

  @Property(tries = 2000)
  @Tag("OO-001.5")
  @Label("accept_price_eq_sum: an accepted order's price is the sum of the item prices")
  void acceptPriceEqSum(@ForAll("offers") Offer offer, @ForAll("instants") long now) {
    if (OfferOrderRules.accept(offer, now, "ORD-1") instanceof AcceptResult.Accepted a) {
      long sum = offer.items().stream().mapToLong(i -> i.price().amount()).sum();
      assertEquals(sum, a.order().price().amount());
    }
  }

  @Property(tries = 100)
  @Tag("OO-002.4")
  @Label("delivered_not_cancellable: no event moves a delivered service to cancelled")
  void deliveredNotCancellable(@ForAll DeliveryEvent event) {
    assertEquals(Optional.empty(), OfferOrderRules.step(DeliveryState.DELIVERED, DeliveryEvent.CANCEL));
    assertNotEquals(Optional.of(DeliveryState.CANCELLED), OfferOrderRules.step(DeliveryState.DELIVERED, event));
  }

  /**
   * Open in the model ({@code refunds_le_payments} is tagged open_question),
   * so this property is expected to fail.  If the refund rule is changed to
   * count earlier refunds, the property starts passing, this test fails, and
   * the expectation should be removed along with the Lean theorem's sorry.
   *
   * <p>The seed is fixed so CI always finds the counterexample.  CI starts
   * with no jqwik database, and an unseeded search of 2000 tries sometimes
   * missed it (31 October 2026); locally the database replays the last one.
   */
  @Property(tries = 2000, seed = "1")
  @Tag("OO-003.2")
  @Tag("open-question")
  @ExpectFailure(checkResult = ReportCounterexample.class)
  @Label("refunds_le_payments (open): refunds on an order never exceed what was paid")
  void refundsLePayments(@ForAll("distinctPayments") List<Payment> payments,
                         @ForAll("refundLists") List<Refund> refunds) {
    // The theorem's hypothesis: every refund was accepted against one of the payments.
    List<Refund> accepted = refunds.stream()
        .filter(r -> payments.stream().anyMatch(p -> OfferOrderRules.acceptRefund(p, r)))
        .toList();
    assertTrue(OfferOrderRules.totalRefunded(payments, accepted, "ORD-1")
            <= OfferOrderRules.totalPaid(payments, "ORD-1"),
        "refunded " + OfferOrderRules.totalRefunded(payments, accepted, "ORD-1")
            + " against paid " + OfferOrderRules.totalPaid(payments, "ORD-1")
            + " with payments " + payments + " and refunds " + accepted);
  }

  /** Prints the smallest counterexample jqwik found, the Java side of the Lean doubleRefund case. */
  public static class ReportCounterexample implements Consumer<PropertyExecutionResult> {
    @Override
    public void accept(PropertyExecutionResult result) {
      List<Object> sample = result.falsifiedParameters().orElseThrow();
      System.out.println("refunds_le_payments (open), counterexample after shrinking:");
      System.out.println("  payments: " + sample.get(0));
      System.out.println("  refunds:  " + sample.get(1));
    }
  }

  @Provide Arbitrary<Offer> offers() { return Generators.offers(); }
  @Provide Arbitrary<Long> instants() { return Generators.instants(); }
  @Provide Arbitrary<List<Payment>> distinctPayments() { return Generators.distinctPayments(); }
  @Provide Arbitrary<List<Refund>> refundLists() {
    return Generators.refunds().list().ofMaxSize(4).uniqueElements(Refund::id);
  }
}
