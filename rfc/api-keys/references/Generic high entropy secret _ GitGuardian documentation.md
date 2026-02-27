# Generic high entropy secret _ GitGuardian documentation

**Source:** `Generic high entropy secret _ GitGuardian documentation.pdf`

---

Generic high entropy secret | GitGuardian documentation

1 of 9

Secrets detection engine

Detectors

https://docs.gitguardian.com/secrets-detection/secrets-detect...

Generic Detectors

Generic high entropy secret

Generic high entropy secret
Description
General
The generic high entropy detector aims at catching any high entropy strings being
assigned to a sensitive variable. This statement is pretty wide, therefore to avoid raising many
false alerts, GitGuardian has come up with a range of validation steps and speciﬁcations to reﬁne
the perimeter to look at.

Speciﬁcations
About assignments
An assignment is any statement of the form {assigned_variable} {assignment_token}
{value} , like for instance: my_variable = "HelloWorld" .

For this detector, the {assigned_variable} to ﬁnd must contain one of the following words to
be considered sensitive and therefore valid:
• secret
• token
• api[_.-]?key
• credential
• auth

Example: secret_id is a valid assigned_variable .
The {assignment_token} can be one of the following: : , = , := , => , , , > , ( , <-

Example: a valid assignment could thus be secret_id := {value} or service_credential

2/27/26, 2:48 PM

Generic high entropy secret | GitGuardian documentation

2 of 9

https://docs.gitguardian.com/secrets-detection/secrets-detect...

<- {value}

Finally, the {value} must be be a high entropy string, that is to say it must:
• Follow this regular expression: [a-zA-Z0-9_.+/~$-]([a-zA-Z0-9_.+/=~$-]|\\\\(?!
[ntr\"])){14,1022}[a-zA-Z0-9_.+/=~$-]

• Have a Shannon entropy of at least 3
• Pass the post validation steps (see hereunder)

Example: Overall, secret_id := hj65_klhz/trlupok76 is a valid assignment for this detector
and will be caught.
About backslashes
The backslash \ is part of the secret's charset. Some extra rules were added to avoid raising an
important number of false alerts.
• The backslash cannot be the ﬁrst or the last character of the secret.
• It cannot be followed by an n a t or an r otherwise it would result in a line return, tab or
carriage return.
• The backslash cannot be followed by a quote " , otherwise it would be part of an escape
sequence.
• It cannot be used to write a unicode or ascii hexadecimal representation of a character, this is
why a custom pattern was added to the banlist. This may seem a bit brutal, but it is the best
trade-off between recall and precision that at hand.
For more examples, read sections below.

Revoke the secret
This detector catches generic secrets, hence GitGuardian cannot infer the concerned service. To
properly revoke the secret :
�. Understand what service is impacted.
�. Refer to the corresponding documentation to know how to revoke and rotate the secret.

2/27/26, 2:48 PM

Generic high entropy secret | GitGuardian documentation

3 of 9

https://docs.gitguardian.com/secrets-detection/secrets-detect...

Examples
Examples that WILL be caught

- text: |
api_key = hj65_klhz/trlupok76
apikey: hj65_klhz/trlupok76
- text: |
secret_access = hj65_klhz/trlupok76
apikey: hj65_klhz/trlupok76
- text: |
o.set("auth", "bsaruceobkoraebisroaecbu89")
apikey: bsaruceobkoraebisroaecbu89
- text: |
token := buaroeuboesanubo234reacubrch
apikey: buaroeuboesanubo234reacubrch
- text: |
something_token := buaroeuboesanubo234reacubrch
apikey: buaroeuboesanubo234reacubrch
- text: |
set_apikey(buaroeuboesanubo234reacubrch)
apikey: buaroeuboesanubo234reacubrch
- text: |
secret: d1Hb1f\b497XGT75989e
apikey: d1Hb1f\b497XGT75989e

Examples that WILL NOT be caught
• The high entropy string is too short :

- text: |
api_key = hj65_klhz/trlu

• The entropy of the string is not high enough

2/27/26, 2:48 PM

Generic high entropy secret | GitGuardian documentation

4 of 9

https://docs.gitguardian.com/secrets-detection/secrets-detect...

- text: |
secret = xob1xob1xob1xob1xob1xob1xob1

• The assigned variable is not considered sensitive

- text: |
object_id = hj65_klhz/trlupok76

• The high entropy string is not part of an assignment

- text: |
my high entropy api_key
hj65_klhz/trlupok76

• The high entropy string contains an excluded pattern (see banlist hereunder)

- text: |
secret = aes.hj65_klhz/trlupok76

• The backslash character cannot be part of a unicode character hexadecimal representation:

- text: token=\u4356\u6543
apikey: \u4356\u6543

Details for Generic high entropy secret
• High Recall: False
• Validity Check: False
• Minimum Number of Matches: 1
• Occurrences found for one million commits: 7153

2/27/26, 2:48 PM

Generic high entropy secret | GitGuardian documentation

5 of 9

https://docs.gitguardian.com/secrets-detection/secrets-detect...

• Preﬁxed: False
• PreValidators:
Here is a list of the validation steps the document must pass before being analyzed.

- type: FilenameBanlistPreValidator
banlist_extensions: []
banlist_filenames:
- hash
- list/k.txt$
- list/plex.txt$
- \.csproj$
- tg/mtproto\.json
check_binaries: false
- type: ContentWhitelistPreValidator
patterns:
- (secret|token|api[_.-]?key|credential|auth)

• PostValidators:
Here is a list of the validation steps the matched string must pass after being caught.

- type: MinimumDigitsPostValidator
digits: 2
- type: EntropyPostValidator
entropy: 3
- type: ValueBanlistPostValidator
patterns:
- ^id[_.-]
- ^mid[_.-]
- ^mnp[_.-]
- ^auth[_.-]
- ^trnsl[_.-]
- ^oqs_kem[_.-]
- ^pos[_.-]
- ^new[_.-]
- ^aes[_.-]
- ^wpa[_.-]
- ^ec[_.-]
- ^sec[_.-]
- ^zte[_.-]

2/27/26, 2:48 PM

Generic high entropy secret | GitGuardian documentation

6 of 9

https://docs.gitguardian.com/secrets-detection/secrets-detect...

- ^com\.
- parentkey
- auto
- enrich
- frontend
- options
- layout
- group
- field
- gatsby
- transform
- random
- ^tls[_.-]
- '12345'
- '4321'
- abcd
- _size$
- ^pub
- test
- country
- '[_.-]length$'
- template
- \.get
- get[_.-]
- preview
- alpha
- beta
- fake
- ^- keyring
- web[_.-]?app
- ^ds[_.-[token[_.-]
- ^pk[_.-]
- ^aizasy
- example
- ^0x[0-9a-fA-F]+$
- "dev[/\\_-]"
- "[/\\_-]dev"
- "([^a-z0-9]|^)v?\\d\\.\\d{1,3}\\.\\d{1,3}[_.-]"
- "^[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{1,2}[=+]"
- ^/tmp/
- ^\$2[abxy]\$ # bcrypt hash
- \\u[a-f0-9]{4}

2/27/26, 2:48 PM

Generic high entropy secret | GitGuardian documentation

7 of 9

https://docs.gitguardian.com/secrets-detection/secrets-detect...

- \\x[a-f0-9]{2}
- type: ContextWindowBanlistPostValidator
window_width: 30
window_type: left
patterns:
- token_?address
- publishable_?key
- author
- sha
- propert(y|ies)
- foreign
- pubkey
- secret_key_base
- authenticity_token
- "credentials\\(['\"][a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]
{4}-[a-f0-9]{12}$"
- "(?-i:(((?<![A-Z])Id(?![a-z]))|((?<![A-Z])ID(?![A-Z]))|((?<![az])id(?![a-z])))[^0-9@&\\n]{0,15}[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}[a-f0-9]{4}-[a-f0-9]{12}$)"
- type: ContextWindowBanlistPostValidator
window_width: 30
patterns:
- public[_.-]?key
- key[_.-]?user
- key[_.-]?id
- token[_.-]?id
- credential[_.-]?id
- document_?key
- client[_.-]?id # alone, this is not a secret
- secret[_.-]?id # alone, this is not a secret
- licensekey
- \.jpe?g
- \.png
- theme
- playlist
- hash
- sha
- localhost
- 127\.0\.0.\.1
- test
- xsrf
- csrf
- type: AssignmentBanlistPostValidator

2/27/26, 2:48 PM

Generic high entropy secret | GitGuardian documentation

8 of 9

https://docs.gitguardian.com/secrets-detection/secrets-detect...

patterns:
- 'id_token'
- '(credentials|session|secrets)id'
- 'encrypted'
- 'postman[_-]token'
- '^credentialsjson$'
- 'tokenizer'
- '^next[_-]?page[_-]?token'
- '^previous[_-]?page[_-]?token'
- '^ahoy_visit(or)?_token$'
- 'uuid'
- 'authorid'
- 'algolia_search_(only_)?api_key'
- type: HeuristicPostValidator
filters:
- url
- date
- file_name
- number
- heuristic_path
- type: DictFilterPostValidator

Was this page helpful?

Last updated on Feb 2, 2026

Something we didn’t cover?
See our Roadmap

Subscribe on GitHub

Submit a request

API status

2/27/26, 2:48 PM

Generic high entropy secret | GitGuardian documentation

9 of 9

https://docs.gitguardian.com/secrets-detection/secrets-detect...

Subscribe to our newsletter
Emai address
By submitting this form, I agree to GitGuardian’s Privacy Policy

2/27/26, 2:48 PM

