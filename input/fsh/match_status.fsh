CodeSystem: MatchStatusCS
Id: match-status-cs
Title: "Match Status Code System"
Description: "Codes representing patient match certainty and status for Record Location Service (RLS) discovery queries."
* #certain "Certain Match" "Demographic matching yielded a single 100% verified patient match."
* #multiple-potential "Multiple Potential Matches" "Demographic matching yielded multiple candidate matches requiring interactive resolution at the target Data Holder."

ValueSet: MatchStatusVS
Id: match-status-vs
Title: "Match Status Value Set"
Description: "Value set containing match status codes for RLS discovery responses."
* include codes from system MatchStatusCS

Extension: MatchStatusExtension
Id: match-status-extension
Title: "Match Status Extension"
Description: "An extension to indicate whether an RLS discovery entry represents a 1-to-1 certain match or multiple potential matches."
* value[x] only Coding
* valueCoding from MatchStatusVS (required)
* ^context[+].type = #element
* ^context[=].expression = "Bundle.entry.search"
* ^context[+].type = #element
* ^context[=].expression = "Endpoint"
