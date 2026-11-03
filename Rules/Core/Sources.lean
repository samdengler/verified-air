import Lean

/-!
# Sources

Where the rules come from.  Each rule names its sources with
{lit}`@[source "<key> ..."]`, and each key is listed here once, with the kind
of source, a title and a link.  The attribute rejects a key that is not here,
and the status executable fails on a rule with an EARS ID and no source.
-/

namespace Rules.Core

/-- The kind of a source a rule is written from.  A rule whose only sources
are the modeller's is an assumption until someone confirms it. -/
inductive SourceKind
  /-- A published industry standard, such as IATA's ONE Order material. -/
  | standard
  /-- A law or a regulation. -/
  | regulation
  /-- The airline's own written policy, contract or procedure. -/
  | policy
  /-- The rule set of a rules engine in production. -/
  | engine
  /-- Application source code. -/
  | code
  /-- An existing test suite. -/
  | test
  /-- Production data or logs. -/
  | data
  /-- An answer or an interview from a subject matter expert. -/
  | sme
  /-- The modeller's own choice, where no source states the rule. -/
  | modeller
  deriving DecidableEq, Repr, Inhabited

/-- The name of a kind of source, as the status file and the pages show it. -/
def SourceKind.label : SourceKind → String
  | .standard => "standard"
  | .regulation => "regulation"
  | .policy => "policy"
  | .engine => "engine"
  | .code => "code"
  | .test => "test"
  | .data => "data"
  | .sme => "sme"
  | .modeller => "modeller"

/-- A source the rules cite: the key a rule names it by, its kind, a title in
our words and a link. -/
structure Source where
  key : String
  kind : SourceKind
  title : String
  url : String
  deriving Repr, Inhabited

/-- Every source the rules cite.  The titles name IATA's pages; nothing from
them is quoted.  The two modeller sources mark rules written for the proof of
concept where no source states them. -/
def sources : List Source := [
  { key := "armi-general-guidance", kind := .standard,
    title := "ARMI, General Guidance",
    url := "https://standards.atlassian.net/wiki/spaces/ARMI/pages/584318980/General+Guidance" },
  { key := "armi-ordca2", kind := .standard,
    title := "IATA capability ORDCA2",
    url := "https://retailing.iata.org/armi/docs/ORDCA2/" },
  { key := "armi-ordpen", kind := .standard,
    title := "IATA capability ORDPEN",
    url := "https://retailing.iata.org/armi/docs/ORDPEN/" },
  { key := "armi-ordsts", kind := .standard,
    title := "IATA capability ORDSTS",
    url := "https://retailing.iata.org/armi/docs/ORDSTS/" },
  { key := "armi-ordwpm", kind := .standard,
    title := "IATA capability ORDWPM",
    url := "https://retailing.iata.org/armi/docs/ORDWPM/" },
  { key := "armi-paycmt", kind := .standard,
    title := "IATA capability PAYCMT",
    url := "https://retailing.iata.org/armi/docs/PAYCMT/" },
  { key := "armi-payord", kind := .standard,
    title := "IATA capability PAYORD",
    url := "https://retailing.iata.org/armi/docs/PAYORD/" },
  { key := "easd-add-ancillary", kind := .standard,
    title := "EASD guide, Customer Adds an Ancillary to Existing Order",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/842301482" },
  { key := "easd-add-ancillary-seats", kind := .standard,
    title := "EASD guide, Customer Adds an Ancillary to Existing Order - Seat Availability",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/842268814" },
  { key := "easd-add-ancillary-services", kind := .standard,
    title := "EASD guide, Customer Adds an Ancillary to Existing Order - Service list",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/842301531" },
  { key := "easd-airline-notifies-seller", kind := .standard,
    title := "EASD guide, Airline notifies Seller of changes to an Order",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/815202352" },
  { key := "easd-bundles", kind := .standard,
    title := "EASD guide, Bundles",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574619818" },
  { key := "easd-cancellation-of-order-items", kind := .standard,
    title := "EASD guide, Cancellation of Order Items",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574783569/Cancellation+of+Order+Items" },
  { key := "easd-commission-and-margin", kind := .standard,
    title := "EASD guide, Commission and Margin",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574849050" },
  { key := "easd-create-order-without-payment", kind := .standard,
    title := "EASD guide, Create Order Without Payment",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574455879/Create+Order+Without+Payment" },
  { key := "easd-currency-in-monetary-amounts", kind := .standard,
    title := "EASD guide, Currency in Monetary Amounts",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/749305864/Currency+in+Monetary+Amounts" },
  { key := "easd-discounts", kind := .standard,
    title := "EASD guide, Discounts",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574849038/Discounts" },
  { key := "easd-inform-of-impacted-dependent-services", kind := .standard,
    title := "EASD guide, Inform of Impacted Dependent Services",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/672825400" },
  { key := "easd-modification-of-an-order", kind := .standard,
    title := "EASD guide, Modification of an Order",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574619782/Modification+of+an+Order" },
  { key := "easd-multiple-payment-methods", kind := .standard,
    title := "EASD guide, Use of multiple payment methods",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/2592899087/Use+of+multiple+payment+methods+to+pay+for+a+single+item" },
  { key := "easd-offer-conditions-and-restrictions", kind := .standard,
    title := "EASD guide, Offer Conditions and Restrictions",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574816307/Offer+Conditions+and+Restrictions" },
  { key := "easd-offer-restrictions", kind := .standard,
    title := "EASD guide, Offer Restrictions",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574259692/Offer+Restrictions" },
  { key := "easd-offers", kind := .standard,
    title := "EASD guide, Offers",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/600637464" },
  { key := "easd-order", kind := .standard,
    title := "EASD guide, Order",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574849062/Order" },
  { key := "easd-order-history", kind := .standard,
    title := "EASD guide, Order History",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574652557/Order+History" },
  { key := "easd-order-versioning", kind := .standard,
    title := "EASD guide, Order Versioning",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574259659/Order+Versioning" },
  { key := "easd-pay-for-an-existing-order", kind := .standard,
    title := "EASD guide, Pay for an Existing Order",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574226556/Pay+for+an+Existing+Order" },
  { key := "easd-pay-offline-using-redirection", kind := .standard,
    title := "EASD guide, Pay Offline Using Redirection",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574455927/Pay+Offline+Using+Redirection" },
  { key := "easd-payment-simulation", kind := .standard,
    title := "EASD guide, Payment Simulation",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/2593030164/Payment+Simulation" },
  { key := "easd-price-differentials", kind := .standard,
    title := "EASD guide, Price Differentials",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574554213/Price+Differentials" },
  { key := "easd-reusable-amount", kind := .standard,
    title := "EASD guide, Customer requests a cancellation to paid Order or OrderItems resulting in a Reusable amount",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/817594921" },
  { key := "easd-seat-map-and-availability", kind := .standard,
    title := "EASD guide, Seat Map and Availability",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574586953" },
  { key := "easd-seller-follow-up-actions", kind := .standard,
    title := "EASD guide, Seller Follow-up Actions",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574849094" },
  { key := "easd-shop-for-ancillaries", kind := .standard,
    title := "EASD guide, Shop for Ancillaries",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574226524" },
  { key := "easd-taxes-fees-and-charges", kind := .standard,
    title := "EASD guide, Taxes, Fees, and Charges",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574455915/Taxes+Fees+and+Charges" },
  { key := "easd-time-limits", kind := .standard,
    title := "EASD guide, Time Limits",
    url := "https://standards.atlassian.net/wiki/spaces/EASD/pages/574423066/Time+Limits" },
  { key := "iata-r797", kind := .standard,
    title := "IATA Resolution 797",
    url := "https://www.iata.org/contentassets/72cbd60393ff42b5975d90ce9e049a7d/oneorder-resolution-797.pdf" },
  { key := "oa-paid-cancellation", kind := .standard,
    title := "Order Accounting, Customer requests a cancellation to paid Order or OrderItems",
    url := "https://standards.atlassian.net/wiki/spaces/OA/pages/844333086" },
  { key := "oa-partial-refund-penalty", kind := .standard,
    title := "Order Accounting, Customer requests a cancellation to paid Order or OrderItems resulting in Partial Amount Refunded with a Forfeited amount and a penalty with reporting to Accounting",
    url := "https://standards.atlassian.net/wiki/spaces/OA/pages/844333143" },
  { key := "oa-service-consumption", kind := .standard,
    title := "Order Accounting, Service Consumption",
    url := "https://standards.atlassian.net/wiki/spaces/OA/pages/579272705" },
  { key := "swo-clearance-manager", kind := .standard,
    title := "Settlement with Orders, Clearance Manager",
    url := "https://standards.atlassian.net/wiki/spaces/SWO/pages/574259794" },
  { key := "swo-codeset-list", kind := .standard,
    title := "Settlement with Orders, Codeset List",
    url := "https://standards.atlassian.net/wiki/spaces/SWO/pages/574456090" },
  { key := "swo-enhanced-and-simplified-distribution", kind := .standard,
    title := "Settlement with Orders, Enhanced and Simplified Distribution",
    url := "https://standards.atlassian.net/wiki/spaces/SWO/pages/574653091" },
  { key := "swo-financial-and-accounting-systems", kind := .standard,
    title := "Settlement with Orders, Financial and Accounting Systems",
    url := "https://standards.atlassian.net/wiki/spaces/SWO/pages/574554300" },
  { key := "swo-remittance-of-funds", kind := .standard,
    title := "Settlement with Orders, Remittance of Funds",
    url := "https://standards.atlassian.net/wiki/spaces/SWO/pages/574718145" },
  { key := "swo-request-for-clearance", kind := .standard,
    title := "Settlement with Orders, Request for Clearance",
    url := "https://standards.atlassian.net/wiki/spaces/SWO/pages/574259760" },
  { key := "swo-settlement", kind := .standard,
    title := "Settlement with Orders, Settlement",
    url := "https://standards.atlassian.net/wiki/spaces/SWO/pages/574816478" },
  { key := "swo-transfer-of-funds", kind := .standard,
    title := "Settlement with Orders, Transfer of Funds",
    url := "https://standards.atlassian.net/wiki/spaces/SWO/pages/574488849" },
  { key := "pilot-slice", kind := .modeller,
    title := "The pilot slice, simplified and invented for the proof of concept",
    url := "https://github.com/samdengler/verified-air/blob/main/README.md" },
  { key := "model-consistency", kind := .modeller,
    title := "One delivery status table for every area, from the independent critique",
    url := "https://github.com/samdengler/verified-air/blob/main/Rules/OneOrder/Consistency.lean" }
]

/-- The source a key names, if the list has it. -/
def sourceOf? (key : String) : Option Source :=
  sources.find? (·.key == key)

end Rules.Core
