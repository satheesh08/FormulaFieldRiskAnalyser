## 🧠 Formula CPU Risk Analyzer for Salesforce

This Salesforce Lightning Web Component (LWC) helps developers and admins proactively detect **complex formula fields** that may risk hitting **Apex CPU time limits**. It analyzes all formula fields on a specific object and calculates their:


| 🔍 Metric                         | 🧠 Meaning                                                                                                              |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 🧬 **Nesting depth**              | How deep the formula nesting is (e.g., nested `IF`, `AND`, `OR` logic). Deep nesting can hit CPU limits.                |
| 🔗 **Cross-object hops**          | How many relationships the formula travels across (`Account.Owner.Profile.Name` = 2 hops). More hops = more CPU.        |
| 🧠 **Heavy function count**       | Count of expensive functions like `ISCHANGED`, `PRIORVALUE`, `VLOOKUP`, `GEOLOCATION`, `DISTANCE`. These are CPU-heavy. |
| 🔥 **CPU risk level**             | Based on depth, hops, heavy functions, length, and unbalanced parentheses. (High / Medium / Low).                       |
| 💣 **Formula too long**           | Boolean flag if formula exceeds 3000 characters. Can impact performance.                                                |
| 🧍 **Uses \$User / \$RecordType** | Checks if formula references current user or record type — often used in dynamic formulas.                              |
| 📈 **CPU Score**                  | A numerical score derived from multiple factors to quantify complexity/risk.                                            |
| 🚩 **Red Flags**                  | Text field highlighting specific issues found, e.g., “Excessive nesting”, “Unbalanced parentheses”, etc.                |

It uses the **Tooling API** securely via a **Named Credential**, removing the need for manual token management.

---

## 💼 Why It Matters
Salesforce formulas can silently contribute to performance bottlenecks, especially when:

🧬 Nesting gets deep
Deeply nested IF, AND, or CASE statements increase evaluation complexity.

🔗 Cross-object references are chained
Referencing multiple parent objects (e.g., Opportunity.Account.Owner.Profile.Name) increases data traversal and CPU usage.

🔁 Used in multiple automations
When the same formula field is used in multiple Flows, validation rules, or process builders, it's recalculated multiple times.

🧠 Contain heavy functions
Expensive functions like VLOOKUP, ISCHANGED, PRIORVALUE, DISTANCE, GEOLOCATION can cause spikes in CPU time.

🕵️ Used in record-triggered Flows or Apex
When formulas are accessed via triggers or flows, Salesforce recalculates them, impacting total transaction time.

🧮 Used in List Views or Reports
Formula fields on frequently-used list views or report filters slow down loading and query times.

🧱 Include hardcoded logic or IDs
Makes formulas brittle and harder to maintain, often leading to downstream logic errors or misfires.

🔁 Have repeated expressions
Repeating the same logic multiple times within a formula increases processing cost unnecessarily.

📅 Use date/time logic excessively
Functions like NOW(), TODAY(), DATEVALUE() can recalculate on every view/load, increasing overhead.

🧾 Evaluated on large data volumes
In batch Apex or mass updates (e.g., data loads), formula fields contribute to CPU usage per record.

This tool surfaces those risks **before they become production incidents**.

---

## 🚀 Features

* Secure Tooling API access via **Named Credential**
* Lightweight LWC with **dynamic badge indicators**
* Easily extensible

---

## 🧩 Setup Instructions

### 🔑 STEP 1: Create a Connected App (One-Time Setup)

1. **Go to:**
   Setup → **App Manager** → **New Connected App**

2. **Fill in:**

   * **Name:** `ToolingAPI_ConnectedApp`
   * **API Name:** (auto-filled)
   * **Contact Email:** (your email)

3. ✅ **Enable OAuth Settings:**

   * ☑️ Enable OAuth Settings
   * **Callback URL:**
     `https://login.salesforce.com/services/oauth2/callback`
   * **Selected OAuth Scopes:**

     * `Access and manage your data (api)`
     * `Perform requests on your behalf at any time (refresh_token, offline_access)`
     * `Full access (full)`

4. Click **Save**.
   🔑 Note the **Consumer Key** and **Consumer Secret**

> ⏳ Wait 2–10 minutes for it to become available.

---

### 🌐 STEP 2: Create an Auth Provider

1. Go to:
   Setup → **Auth. Providers** → **New**

2. **Provider Type:** `Salesforce`

3. Fill:

   * **Name:** `Salesforce_Tooling_Auth`
   * **Consumer Key:** from Connected App
   * **Consumer Secret:** from Connected App
   * **Authorize Endpoint URL:**
     `https://login.salesforce.com/services/oauth2/authorize`
   * **Token Endpoint URL:**
     `https://login.salesforce.com/services/oauth2/token`

4. Click **Save**
   🔁 Note the **Callback URL** Salesforce generates (you’ll use it in the next step)

---

### 🔁 STEP 3: Update Connected App with Callback URL

1. Go back to:
   Setup → **App Manager** → Find your Connected App → **Edit**

2. Replace the **old Callback URL** with the one from the **Auth Provider** (`https://...force.com/.../services/authcallback/...`)

3. Save again.

---

### 📛 STEP 4: Create a Named Credential

1. Go to:
   Setup → **Named Credentials** → **New**

2. Fill:

| Field                             | Value                                                                        |
| --------------------------------- | ---------------------------------------------------------------------------- |
| **Label**                         | `ToolingAPI`                                                                 |
| **Name**                          | `ToolingAPI`                                                                 |
| **URL**                           | `https://yourInstance.salesforce.com` (e.g., `https://na123.salesforce.com`) |
| **Identity Type**                 | Named Principal                                                              |
| **Authentication Protocol**       | OAuth 2.0                                                                    |
| **Authentication Provider**       | `Salesforce_Tooling_Auth`                                                    |
| **Scope**                         | `full refresh_token offline_access`                                          |
| **Generate Authorization Header** | ☑️ Yes                                                                       |
| **Allow Callouts**                | ☑️ Yes                                                                       |

3. Click **Save** → then click **Authenticate** to complete the OAuth flow.

---

## 🖥️ Usage

1. Navigate to App(FormulaSniffR) Open the App Page (FormulaSniffR).
2. On load, the component:

   * Reads the `objectApiName` from the user.
   * Uses Tooling API to retrieve all formula fields for the selected object.
   * Displays risk indicators for each field

![image](https://github.com/user-attachments/assets/db0d893a-cded-4bc0-a932-e9c1e713616e)
![image](https://github.com/user-attachments/assets/df7aeef2-ae64-452a-99a1-93fe19ed9327)
![image](https://github.com/user-attachments/assets/26ad1c69-d5c3-4f41-bb6e-f6b35e935912)
![image](https://github.com/user-attachments/assets/4e257543-6c95-43bf-9f9e-966590cc1e80)

## 📅 Salesforce Compatibility

* API Version: `60.0` (Summer '24)
* Works with: Salesforce DX, Scratch Orgs, Sandboxes, Dev Orgs

---

## 🔐 Security
* No secrets (tokens or keys) are stored in this repo.
---
