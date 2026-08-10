# Record Location Service (RLS) and Patient Discovery

This section specifies the technical architecture, protocol requirements, and operational expectations for Client Applications to discover patient record locations across a CMS-aligned network using the FHIR `$match` (Patient Demographics Match) operation.

---

## 1. Architectural Overview & Context

In a CMS-aligned network, discovering where a patient's medical records reside across distributed Data Holders requires an efficient, standardized Patient Discovery mechanism. 

### Key Concepts & Workflow Steps

1. **Dynamic Client Registration Prerequisite**: Prior to invoking Record Location Service (RLS) or Patient Discovery endpoints, the Client Application **MUST** have completed [Dynamic Client Registration](registration.html) with the target Data Holder or RLS hub.
2. **Directory Listing of RLS Endpoints**: Data Holders **SHALL** expose the `$match` operation in their `CapabilityStatement`. The official RLS endpoint URL for a Data Holder's FHIR endpoints **SHALL** be listed in the National Provider Directory, regardless of whether RLS execution is federated across hubs or hosted directly by individual Data Holders.
3. **App Authentication via CSP**: In an IAS workflow, the Client Application first authenticates the patient out-of-band using an accredited Credential Service Provider (CSP) or Identity Provider, receiving an OIDC `id_token` asserting the patient's verified identity at IAL2.
4. **System Access Token (Client Credentials)**: To query the RLS / Patient Discovery endpoint, a registered Client Application authenticates at the Data Holder's token endpoint using `grant_type=client_credentials` with `private_key_jwt` and requests at least the `system/Patient.rs` scope.
5. **No Patient Context in System Access Token**: Unlike patient-facing session tokens, the access token returned from the client credentials exchange carries **no initial patient context** (it is scoped at the system level for RLS query execution).
6. **IAS Verification Header (`X-IAS-ID-Token`)**: For Individual Access Services (IAS) workflows, the Client Application **MUST** include an `X-IAS-ID-Token` HTTP header containing the patient's verified OIDC `id_token`. The `aud` (audience) claim of this `id_token` **MUST** contain the application's `software_id` URI as asserted inside the CMS-signed software statement presented during dynamic registration.
7. **Strict Match Constraints (`onlyCertainMatches=true` & Single Result)**: For IAS workflows, the `$match` request `onlyCertainMatches` parameter **MUST** be set to `true`. Furthermore, Data Holders **SHALL** return at most **one** matched patient record in the response Bundle. If matching yields multiple candidates or ambiguous results, the Data Holder **SHALL** return an empty searchset Bundle (`total: 0`).
8. **`fullUrl` Requirement in SearchSet Response**: Data Holders and RLS hubs responding to `$match` requests **SHALL** return a `Bundle` of type `searchset`. Every `entry` inside the response Bundle **MUST** include a valid `fullUrl` element pointing to the canonical FHIR Patient resource URI or absolute endpoint URL for that matched record.
9. **Auditability (`AuditEvent`)**: Every invocation of the FHIR `$match` operation **SHALL** be auditable by both the requesting client system and the responding Data Holder by generating standard FHIR `AuditEvent` records.

---

## 2. Conformance Requirements

The official key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**, **SHOULD**, **SHOULD NOT**, **RECOMMENDED**, **MAY**, and **OPTIONAL** in this document are to be interpreted as described in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).

1. **Registration Prerequisite**: Client Applications **SHALL** complete [Dynamic Client Registration](registration.html) with the Data Holder or RLS provider prior to calling `$match`.
2. **Capability Statement Declaration**: Data Holders **SHALL** declare support for the Patient `$match` operation in their FHIR `CapabilityStatement` (`CapabilityStatement.rest.resource.operation`).
3. **National Provider Directory Publication**: The RLS endpoint URL for a Data Holder's FHIR server **SHALL** be published in the National Provider Directory, regardless of whether RLS routing is federated across network hubs or hosted locally by the Data Holder.
4. **Client Credentials Authentication**:
   - The Client Application **SHALL** request an access token via `grant_type=client_credentials` using `private_key_jwt` client authentication (`client_assertion`).
   - The Client Application **SHALL** request at least `system/Patient.rs` in the `scope` parameter.
   - The `client_assertion` JWT presented during `client_credentials` authentication **MUST** include the [HL7 UDAP B2B Authorization Extension Object](https://build.fhir.org/ig/HL7/fhir-udap-security-ig/branches/master/b2b.html#b2b-authorization-extension-object) (`hl7-b2b` claim) formatted as follows:
     - `version`: **MUST** be `"1"`.
     - `purpose_of_use`: **MUST** be an array containing `"PATRQT"` (`["PATRQT"]`).
     - `organization_id`: **MUST** be set to the canonical organization URI for the requesting entity as published in the National Provider Directory (NPD).
   - Data Holders **SHALL NOT** return patient launch context inside the resulting client credentials token response.
5. **IAS Identity Header (`X-IAS-ID-Token`)**:
   - For Individual Access Services (IAS) workflows, the Client Application **SHALL** include the `X-IAS-ID-Token: <jwt>` HTTP header in the `$match` request.
   - The header value **MUST** contain a valid OIDC `id_token` asserting the patient's verified identity (e.g. IAL2 verification).
   - The `aud` (audience) claim of the `id_token` **MUST** contain the `software_id` URI specified in the Client Application's CMS-signed software statement presented during [Dynamic Client Registration](registration.html).
   - Data Holders **SHALL** validate that `aud` matches the registered `software_id`, and verify the signature, expiration, and issuer of the `X-IAS-ID-Token` header before processing the match query.
6. **IAS Certain Match & Single Result Restrictions**:
   - For IAS workflows, the `$match` request `onlyCertainMatches` parameter **MUST** be set to `true`.
   - Data Holders **SHALL** return at most **one** (`1`) matched patient record in the response `Bundle`.
   - If demographic matching results in zero matches or multiple candidate matches, the Data Holder **SHALL** return an HTTP `200 OK` response with a searchset `Bundle` containing `total: 0` and an empty `entry` array.
7. **Demographic & Identifier Search Parameters**:
   - The `$match` request body **SHALL** follow the standard FHIR `$match` `Parameters` format, containing a `Patient` resource in the `resource` parameter.
   - Additional identifiers known to the submitter (e.g., MBI, MRN, SSN) **MAY** be submitted within the `Patient` resource payload. Refer to [Identity and Patient Matching](statements-on-identity.html) for specific use cases and disambiguation rules.
8. **Response Bundle & `fullUrl` Requirement**:
   - Data Holders **SHALL** respond with HTTP `200 OK` and a `Bundle` of type `searchset`.
   - Every `entry` element inside the response `Bundle` **MUST** include a non-empty `fullUrl` representing the absolute URL of the matched Patient resource (or absolute Data Holder endpoint).
   - Each entry `search.score` **SHOULD** reflect the match confidence score (ranging from `0.0` to `1.0`).
9. **AuditEvent Recording**:
   - Every execution of the `$match` operation **SHALL** be recorded in an `AuditEvent` resource by the Data Holder capturing the requesting client identity (`client_id`), timestamp, `$match` parameter hashes, and resulting match outcome.

---

## 3. Protocol Sequence Diagram

The following sequence illustrates an IAS workflow: the Client Application authenticates the patient out-of-band via a Credential Service Provider (CSP) to obtain an OIDC `id_token`, obtains a system-level access token via client credentials presenting the `hl7-b2b` authorization extension claim, and queries the FHIR `$match` endpoint presenting the `X-IAS-ID-Token` header and demographic search parameters.

<p align="center">
  <img src="rls-patient-discovery.svg" alt="RLS and Patient Discovery Sequence Diagram" style="max-width: 100%; height: auto;" />
</p>

```plantuml
@startuml
scale max 1000 width
autonumber
actor "Patient" as Patient
participant "Client Application" as Client
participant "Credential Service Provider (CSP)" as CSP
participant "National Provider Directory" as Directory
participant "Data Holder /token" as Token
participant "Data Holder $match Endpoint" as RLS
database "Data Holder Audit Log" as Audit

group 1. Patient Verification & Directory Discovery
Patient -> Client: Initiate Patient Discovery
Client -> CSP: Authenticate Patient (IAL2)
CSP --> Client: Issue Verified OIDC id_token
Client -> Directory: Lookup Data Holder RLS Endpoint & CapabilityStatement
Directory --> Client: Return RLS Endpoint URL & CapabilityStatement ($match supported)
end

group 2. Client Authentication & RLS Query ($match)
Client -> Token: POST /token (grant_type=client_credentials, scope=system/Patient.rs, client_assertion with hl7-b2b)
Token --> Client: HTTP 200 OK { access_token, scope: "system/Patient.rs" } (No patient context)
Client -> RLS: POST /Patient/$match\nHeader: Authorization: Bearer <access_token>\nHeader: X-IAS-ID-Token: <id_token>\nBody: Parameters { resource: Patient, onlyCertainMatches: true }
RLS -> RLS: Validate access_token, X-IAS-ID-Token signature & Enforce onlyCertainMatches (Max 1 Result)
RLS -> Audit: Log AuditEvent (Client ID, Patient Query, Match Outcome)
RLS --> Client: HTTP 200 OK Bundle (type=searchset, total: 1 or 0, entry[].fullUrl REQUIRED)
end
@enduml
```

---

## 4. HTTP Exchange Examples

### Step 1: System Access Token Request (`POST /token`)

```http
POST /oauth/token HTTP/1.1
Host: dataholder.example.org
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=eyJhbGciOiJFUzM4NCIsImtpZCI6ImFwcC1rZXktMSJd...[client-assertion-jwt]...
&scope=system%2FPatient.rs
```

#### Example `client_assertion` JWT Payload (with `hl7-b2b` Extension)

```json
{
  "iss": "dh_client_982347102934",
  "sub": "dh_client_982347102934",
  "aud": "https://dataholder.example.org/oauth/token",
  "exp": 1781817583,
  "iat": 1781817283,
  "jti": "b2b-token-req-99120482",
  "hl7-b2b": {
    "version": "1",
    "purpose_of_use": [
      "PATRQT"
    ],
    "organization_id": "https://directory.cms.gov/organizations/org-99281"
  }
}
```

#### Token Response (No Patient Context)

```http
HTTP/1.1 200 OK
Content-Type: application/json;charset=UTF-8
Cache-Control: no-store

{
  "access_token": "eyJhbGciOiJSUzI1Ni...[system_access_token]...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "system/Patient.rs"
}
```

---

### Step 2: Patient Discovery Request (`POST /Patient/$match`)

```http
POST /fhir/Patient/$match HTTP/1.1
Host: dataholder.example.org
Authorization: Bearer eyJhbGciOiJSUzI1Ni...[system_access_token]...
X-IAS-ID-Token: eyJhbGciOiJSUzI1NiIsImtpZCI6ImNzcC1rZXktMSJd...[verified-id-token]...
Content-Type: application/fhir+json

{
  "resourceType": "Parameters",
  "parameter": [
    {
      "name": "resource",
      "resource": {
        "resourceType": "Patient",
        "name": [
          {
            "family": "Smith",
            "given": ["Jane"]
          }
        ],
        "birthDate": "1985-04-12",
        "gender": "female",
        "identifier": [
          {
            "system": "http://hl7.org/fhir/sid/us-mbi",
            "value": "1EG4-TE5-MK73"
          }
        ]
      }
    },
    {
      "name": "onlyCertainMatches",
      "valueBoolean": true
    },
    {
      "name": "count",
      "valueInteger": 1
    }
  ]
}
```

---

### Step 3: Patient Discovery Response (`Bundle` with Mandatory `fullUrl`, Max 1 Result)

```http
HTTP/1.1 200 OK
Content-Type: application/fhir+json;charset=UTF-8

{
  "resourceType": "Bundle",
  "type": "searchset",
  "total": 1,
  "entry": [
    {
      "fullUrl": "https://dataholder.example.org/fhir/Patient/pat-88321",
      "resource": {
        "resourceType": "Patient",
        "id": "pat-88321",
        "name": [
          {
            "family": "Smith",
            "given": ["Jane"]
          }
        ],
        "birthDate": "1985-04-12",
        "gender": "female"
      },
      "search": {
        "mode": "match",
        "score": 0.98
      }
    }
  ]
}
```

---

## 5. Auditability Expectations (`AuditEvent`)

Every execution of the `$match` operation **MUST** be recorded in an audit trail. Data Holders **SHALL** generate a FHIR `AuditEvent` resource for each Patient Discovery query. 

> [!NOTE]
> Detailed profiles and implementation guidelines for the `AuditEvent` resource supporting RLS and Patient Discovery will be formally incorporated in a subsequent release.

Key audit attributes recorded include:
- **`type`**: Restful Operation (`http://terminology.hl7.org/CodeSystem/audit-event-type` code `rest`).
- **`subtype`**: Operation `$match` (`http://hl7.org/fhir/restful-interaction` code `operation`).
- **`agent`**: The authenticated Client Application (`client_id`) and user identity extracted from `X-IAS-ID-Token`.
- **`entity`**: The query parameters (hashed demographic search parameters) and resulting matched Patient ID (`fullUrl`).

---

## 6. Points for Discussion

> [!IMPORTANT]
> **Placement of the ID Token**: The placement of the OIDC `id_token` (e.g. `X-IAS-ID-Token` header) in this workflow is **not finalized** and remains under active workgroup discussion. While the verified patient assertion could theoretically be conveyed using SMART Permission Tickets during token exchange, doing so for initial Patient Discovery would result in a clunky, multi-hop interface. The workgroup is evaluating the optimal balance between header assertions and ticket-based mechanisms.
