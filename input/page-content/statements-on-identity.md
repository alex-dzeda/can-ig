# Identity and Patient Matching

This section specifies rules and operational guidance for asserting identity claims and performing patient matching within a CMS-aligned network.

---

## Verified Claims vs. Disambiguation Claims

When evaluating identity assertions encapsulated in a **SMART Permission Ticket** (specifically within `subject.patient` and `subject_identity_evidence`), Data Holders **SHALL** distinguish between verified identity claims established by a Credential Service Provider (CSP) or Identity Provider (IdP) versus supplementary demographic parameters supplied for disambiguation.

### Disambiguation Matching Policy

Information in the `subject.patient` parameter of a ticket that is **not** present in a verified claim of an embedded `id_token` (within `subject_identity_evidence`) **MAY ONLY** be used to disambiguate when a matching algorithm from the *CMS-Aligned Patient Matching Specification* returns multiple potential candidate results.

### Disambiguation Example (e.g. MBI / Medicare Beneficiary Identifier)

Consider a scenario where a Data Holder's local Master Patient Index (MPI) matching algorithm evaluates verified demographic claims (e.g. verified Name, Date of Birth, and SSN) and yields **3 potential candidate records** with identical matching scores.

If the ticket's `subject.patient` payload includes a supplementary identifier such as a Medicare Beneficiary Identifier (MBI) or local MRN:
- If the supplied MBI matches exactly **one** of those 3 candidate records, the Data Holder **MAY** consider this a valid, unambiguous patient match.
- Unverified parameters in `subject.patient` **SHALL NOT** be used to create a new match out of zero candidates if the core verified identity claims fail to match.

---

## Identity Evidence Structure (`subject_identity_evidence`)

For Patient Self-Access (Individual Access Services), identity evidence is carried in the `subject_identity_evidence` claim of the SMART Permission Ticket as an embedded OIDC `id_token`:

```json
"subject_identity_evidence": [
  {
    "source": "embedded",
    "token_type": "id_token",
    "jwt": "eyJhbGciOiJSUzI1NiIs..."
  }
]
```

Data Holders **SHALL** verify the signature, issuer trust, and validity window of the embedded `id_token` to confirm the patient's identity assurance level (e.g. NIST SP 800-63-3 IAL2).

