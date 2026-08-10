# End to End Workflow Narrative

This section provides a complete walkthrough of how Client Applications interact with CMS-Aligned Networks and Data Holders across two distinct operational pathways:

1. **Pathway A: Broad Network Discovery (Network RLS Search)** - Used when patient record locations are unknown.
2. **Pathway B: Targeted Direct Access (1-Step Token Exchange)** - Used when the target Data Holder is known.

---

## Registration Phase (Universal Prerequisite)

Regardless of query pathway, all Client Applications complete **RFC 7591 Dynamic Client Registration** once per target Data Holder or Network Authorization Server:
- **CMS App Library / NPD Listing**: App registers with CMS and obtains a CMS-signed software statement.
- **Dynamic Registration (`POST /register`)**: App submits `software_statement` + `client_assertion` (RFC 7523 key possession proof signed by its JWKS key).
- **Outcome**: Data Holder issues a unique `client_id` bound to the app's verified `jwks_uri`.

---

## Pathway A: Broad Network Discovery (Network RLS Search)

When a patient opens an application for the first time and wants to discover records across a network without knowing specific health system endpoints:

<p align="center">
  <img src="end-to-end-narrative.svg" alt="Pathway A Broad Network Discovery Sequence Diagram" style="max-width: 100%; height: auto;" />
</p>

```plantuml
@startuml
scale max 1000 width
autonumber
actor "Patient" as User
participant "Client App" as App
participant "Credential Service Provider (CSP)" as CSP
participant "Network RLS Endpoint" as RLS
participant "Data Holder /token" as DH_Token
participant "Data Holder FHIR API" as DH_FHIR

User -> App: 1. Launch App & Request Record Discovery
App -> CSP: 2. Authenticate Patient (IAL2 Proof)
CSP --> App: 3. Return OIDC id_token
App -> RLS: 4. POST /Patient/$match (X-IAS-ID-Token: id_token, Parameters: Patient Demographics)
RLS -> RLS: 5. Fan-out Search & Evaluate Network eMPI (onlyCertainMatches=true)
RLS --> App: 6. HTTP 200 OK Bundle searchset (List of Data Holder Endpoints)
App -> DH_Token: 7. POST /token (grant_type=token-exchange, subject_token=SMART Ticket)
DH_Token -> DH_Token: 8. Verify presenter_binding.jkt & Issue access_token
DH_Token --> App: 9. HTTP 200 OK { access_token, patient: "pat-88321" }
App -> DH_FHIR: 10. GET /Patient/pat-88321/Observation (Authorization: Bearer <access_token>)
DH_FHIR --> App: 11. Return FHIR Clinical Bundle
@enduml
```

### Steps in Pathway A:
1. **Patient Authentication**: App authenticates patient via CSP, receiving an OIDC `id_token` (IAL2).
2. **Network RLS Query (`$match`)**: App sends `POST /Patient/$match` to the **Network RLS endpoint** with `X-IAS-ID-Token` header.
3. **Endpoint Discovery**: Network RLS returns a searchset `Bundle` listing the specific Data Holder endpoints where matching patient records were found.
4. **Targeted Token Exchange**: App presents a SMART Permission Ticket to each discovered Data Holder's `POST /token` endpoint to receive a FHIR `access_token`.

---

## Pathway B: Targeted Direct Access (1-Step Token Exchange)

When the target Data Holder is already known (e.g. selected by the patient, discovered in NPD, or associated with a prior claim), the application **skips `$match` entirely** and executes 1-step direct token exchange:

<p align="center">
  <img src="end-to-end-narrative_001.svg" alt="Pathway B Targeted Direct Access Sequence Diagram" style="max-width: 100%; height: auto;" />
</p>

```plantuml
@startuml
scale max 1000 width
autonumber
actor "Patient" as User
participant "Client App" as App
participant "Ticket Issuer / CSP" as Issuer
participant "Data Holder /token" as DH_Token
participant "Data Holder FHIR API" as DH_FHIR

User -> App: 1. Select Known Data Holder (e.g., Mayo Clinic)
App -> Issuer: 2. Obtain SMART Permission Ticket (with subject.patient & subject_identity_evidence)
Issuer --> App: 3. Return Signed SMART Permission Ticket JWT
App -> DH_Token: 4. POST /token (grant_type=token-exchange, subject_token=Ticket, client_assertion=private_key_jwt)
DH_Token -> DH_Token: 5. Silent Match: Verify presenter_binding.jkt & Match subject.patient to Local eMPI
DH_Token --> App: 6. HTTP 200 OK { access_token, patient: "pat-88321" }
App -> DH_FHIR: 7. GET /Patient/pat-88321/Condition (Authorization: Bearer <access_token>)
DH_FHIR --> App: 8. Return FHIR Clinical Data
@enduml
```

### Steps in Pathway B:
1. **Direct Token Exchange (`POST /token`)**: App presents the SMART Permission Ticket directly to the Data Holder's token endpoint using `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`.
2. **1-Step Silent Resolution**: The Data Holder's authorization server verifies `presenter_binding.jkt` against the client's `client_assertion` key, validates `subject_identity_evidence`, and matches `subject.patient` demographics to local records.
3. **Token Issuance**: Data Holder returns `{ access_token, patient: "pat-88321" }` in **a single HTTP round-trip**.

---

## Ambiguous Match Fallback (`interaction_required`)

If silent identity matching yields multiple candidate records at a Data Holder during `POST /token`:
1. Data Holder returns `HTTP 400 Bad Request` with `error="interaction_required"` and a single-use `launch` context handle.
2. Client App opens an in-app browser view to `GET /authorize?client_id=...&launch=ctx-abc123XYZ`.
3. Patient interactively confirms their identity at the Data Holder.
4. Data Holder issues an authorization code, which the App exchanges at `POST /token` for the final `access_token`.
