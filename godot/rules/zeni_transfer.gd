class_name RuleZeniTransfer
extends RefCounted
## Pure validation/staging; only CoopRoom commits the pair on the host's main thread.
const MAX_TRANSFER := 1000000000
const MAX_BALANCE := 1000000000000
const COOLDOWN := 1.0
static func whole_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value))
static func amount_error(amount: Variant) -> String:
	if not whole_number(amount) or amount<1: return "Enter a whole zeni amount of at least 1."
	if amount>MAX_TRANSFER: return "Send at most 1,000,000,000 zeni per transfer."
	return ""
static func valid_balance(value: Variant) -> bool:
	return whole_number(value) and value>=0 and value<=MAX_BALANCE
static func plan(sender: Variant,receiver: Variant,amount: Variant) -> Dictionary:
	var error := amount_error(amount)
	if error!="": return {"ok":false,"error":error}
	if not valid_balance(sender) or not valid_balance(receiver):
		return {"ok":false,"error":"That fighter's zeni balance is outside the supported range."}
	var count := int(amount)
	var from_balance := int(sender)
	var to_balance := int(receiver)
	if count>from_balance: return {"ok":false,"error":"You do not have enough zeni."}
	# Check before addition; all arithmetic stays exactly representable in JSON numbers.
	if to_balance>MAX_BALANCE-count: return {"ok":false,"error":"That player cannot hold more than 1,000,000,000,000 zeni."}
	return {"ok":true,"amount":count,"sender":from_balance-count,"receiver":to_balance+count}
static func format_amount(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	for i in digits.length():
		if i>0 and (digits.length()-i)%3==0: out += ","
		out += digits[i]
	return out
