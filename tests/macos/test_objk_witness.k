objk protocol Labelable {
    require label() -> text
}

objk protocol Scorable {
    require score() -> int
    require adjust(amount: int) -> int
}

objk protocol Base {
    require id() -> int
}

objk protocol Detail extends Base {
    require amount(x: int) -> int
}

objk object Badge conforms Labelable, Scorable {
    method label() -> text = badgeLabel
    method score() -> int = badgeScore
    method adjust(amount: int) -> int = badgeAdjust
}

objk object Ledger conforms Detail {
    method id() -> int = ledgerId
    method amount(x: int) -> int = ledgerAmount
}

objk object DoubleBadge extends Badge {
    method score() -> int = doubleBadgeScore
}

func badgeLabel(runtime, self) { emit okKGet(runtime, self, "label") }
func badgeScore(runtime, self) { emit okKGet(runtime, self, "score") }
func badgeAdjust(runtime, self, amount) { emit doKSet(runtime, self, "score", badgeScore(runtime, self) + amount) }
func doubleBadgeScore(runtime, self) { emit badgeScore(runtime, self) * 2 }
func ledgerId(runtime, self) { emit okKGet(runtime, self, "id") }
func ledgerAmount(runtime, self, x) { emit x * 10 + okKGet(runtime, self, "bonus") }

func check(name, expected, actual) {
    if expected != actual { print("[FAIL] " + name); exit("1") }
    print("[PASS] " + name)
}

just run {
    let badge = okKNew(__objkRuntime, Badge)
    let label = okKText(__objkRuntime, "wattage")
    doKText(__objkRuntime, badge, "label", label)
    doKReleaseText(__objkRuntime, label)
    doKSet(__objkRuntime, badge, "score", 11)
    check("conforms first protocol", 1, okKConforms(__objkRuntime, badge, Labelable))
    check("conforms second protocol", 1, okKConforms(__objkRuntime, badge, Scorable))
    check("does not conform to unrelated", 0, okKConforms(__objkRuntime, badge, Detail))
    check("witness count matches first protocol", 1, okKWitnessCount(__objkRuntime, badge, Labelable))
    check("witness count matches second protocol", 2, okKWitnessCount(__objkRuntime, badge, Scorable))
    check("witness slot is requirement handle", 1, okKWitnessSlot(__objkRuntime, badge, Labelable, 1) != 0)
    check("witness implementation resolves", 1, okKWitnessImplementation(__objkRuntime, badge, Labelable, 1) != 0)
    check("slot dispatch zero args", "wattage", okKTextValue(__objkRuntime, okKSlotSend(__objkRuntime, badge, Labelable, 1)))
    check("slot dispatch zero args on second protocol", 11, okKSlotSend(__objkRuntime, badge, Scorable, 1))
    check("slot dispatch one arg", 21, okKSlotSend1(__objkRuntime, badge, Scorable, 2, 10))
    check("slot arity check after slot call", 21, okKGet(__objkRuntime, badge, "score"))
    let ledger = okKNew(__objkRuntime, Ledger)
    doKSet(__objkRuntime, ledger, "id", 7)
    doKSet(__objkRuntime, ledger, "bonus", 1000)
    check("parent requirement uses slot 1", 7, okKSlotSend(__objkRuntime, ledger, Detail, 1))
    check("own requirement uses slot 2", 1030, okKSlotSend1(__objkRuntime, ledger, Detail, 2, 3))
    check("witness covers parent protocol", 2, okKWitnessCount(__objkRuntime, ledger, Detail))
    let double = okKNew(__objkRuntime, DoubleBadge)
    let dblLabel = okKText(__objkRuntime, "double")
    doKText(__objkRuntime, double, "label", dblLabel)
    doKReleaseText(__objkRuntime, dblLabel)
    doKSet(__objkRuntime, double, "score", 21)
    check("inherited conformance visible from subclass", 1, okKConforms(__objkRuntime, double, Scorable))
    check("slot dispatch stays virtual across subclass", 42, okKSlotSend(__objkRuntime, double, Scorable, 1))
    check("subclass witness inherited from parent declaration", 2, okKWitnessCount(__objkRuntime, double, Scorable))
    doKRelease(__objkRuntime, badge)
    doKRelease(__objkRuntime, ledger)
    doKRelease(__objkRuntime, double)
}
