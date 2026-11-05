extends TestCase
func test_amount_validation_caps_and_number_types() -> void:
	for value: Variant in [null,true,false,"5",[],{},0,-1,-100,1.5,NAN,INF,-INF,1000000001,9223372036854775807]:
		ok(RuleZeniTransfer.amount_error(value)!="",str(value))
	for value: Variant in [1,5,5.0,1000000000]: eq(RuleZeniTransfer.amount_error(value),"")
func test_staged_pair_conserves_money_and_checks_receiver_before_adding() -> void:
	var result := RuleZeniTransfer.plan(5000,100,5000.0)
	ok(result.ok); eq(result.sender,0); eq(result.receiver,5100); eq(result.amount,5000)
	ok(not RuleZeniTransfer.plan(10,0,11).ok)
	ok(not RuleZeniTransfer.plan(1000,RuleZeniTransfer.MAX_BALANCE,1).ok)
	var cap := RuleZeniTransfer.plan(RuleZeniTransfer.MAX_TRANSFER,RuleZeniTransfer.MAX_BALANCE-RuleZeniTransfer.MAX_TRANSFER,RuleZeniTransfer.MAX_TRANSFER)
	ok(cap.ok); eq(cap.receiver,RuleZeniTransfer.MAX_BALANCE); eq(cap.sender,0)
	for bad: Variant in [-1,1.2,"10",null,NAN,INF,RuleZeniTransfer.MAX_BALANCE+1]:
		ok(not RuleZeniTransfer.plan(bad,0,1).ok)
		ok(not RuleZeniTransfer.plan(100,bad,1).ok)
func test_formats_and_solo_api_never_change_balance() -> void:
	for value: int in [1,1000,5000,1000000000]:
		eq(RuleZeniTransfer.format_amount(value),{1:"1",1000:"1,000",5000:"5,000",1000000000:"1,000,000,000"}[value])
	var game := RuleGame.new()
	var before: Variant = game.slot.zeni
	eq(game.give_zeni("friend:someone",100),"Join a server to send zeni")
	eq(game.zeni_recipients(),[]); eq(game.slot.zeni,before)
