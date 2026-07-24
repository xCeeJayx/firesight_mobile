# 🚀 FIRESIGHT MOBILE APPLICATION - AGENT INSTRUCTION SPECIFICATION

## System Overview
**FireSight** is a Fire Risk Mapping and Inspection Monitoring System designed for the **Bureau of Fire Protection (BFP) in Lingayen, Pangasinan**. 

The system moves BFP operations beyond simple data storage into an **active, data-driven operational workflow** covering:
1. **Commercial & Occupancy Safety Inspections** (Form BFP-QSF-FSED-061 & BFP-QSF-FSED-009)
2. **Residential House-to-House Fire Safety Scoring** (OLP 35-point Checklist)
3. **Sitio/Purok Urban Vulnerability Risk Mapping & CFPP Action Planning** (OLP Form)
4. **GIS Resource & Emergency Infrastructure Mapping** (Hydrants & Evacuation Centers)

---

## 👥 User Roles & Approval Chain of Command

1. **Public Resident / Citizen:** Accesses public fire risk maps, views nearest evacuation centers, submits local hazard reports, and sends instant fire emergency alerts.
2. **Field Inspector / BFP Officer:** Conducts on-site inspections, logs owner consent/refusal, fills out digital checklists, uploads photo proof of violations, and logs house-to-house safety scores.
3. **Risk Mapping Officer (OLP Unit):** Conducts Sitio/Purok surveys (road width, distance to station, house materials) to feed the risk map and logs CFPP Action Plans (Form 6).
4. **FSES Head (Chief, Fire Safety Enforcement Section):** Assigns Inspection Orders (IOs), sets monthly quotas, reviews inspector submissions, issues Notice to Comply (NTC), and manages escalation.
5. **City/Municipal Fire Marshal (Hepe):** Provides final review and official sign-off for FSIC certificates, abatement orders, or closure notices.

---

## 🗄️ Database Context (Supabase Schema)

The database schema has been updated in Supabase to include:
* `establishments`: `id` (UUID), `name`, `address`, `barangay`, `nature_of_business`, `occupancy_classification`, `risk_level`.
* `inspections`: Linked to `establishment_id` (UUID), includes 3-tier approval (`fses_head_id`, `fire_marshal_id`, `approval_stage`), consent logging (`owner_consent_status`, `refusal_reason`, `owner_signature_url`), and NTC tracking (`ntc_issued`, `ntc_expiry_date`).
* `fire_risk_surveys`: Tracks OLP surveys with `purok_name`, GPS (`latitude`, `longitude`), demography counts, and total scores.
* `hydrants`: Tracks Primewater water sources (`barangay`, `location`, `status`: Operational/Non-Operational, `latitude`, `longitude`).
* `evacuation_centers`: Stores designated shelters per barangay with GPS pins.
* `cfpp_action_plans`: Linked to `fire_risk_surveys` for logging identified gaps and assigned personnel.

---

## 📐 Official BFP Formulas & Scoring Rules

### 1. House-to-House Fire Safety Checklist (35 Items)
Inspectors answer 35 binary criteria (YES/NO). The total `YES` count dictates the interpretation:
* **24 – 35 `YES` Points:** `Ligtas (Safe)` 🟢 (Hex: `#2ECC71`)
* **12 – 23 `YES` Points:** `Maydapat ipangamba (Caution)` 🟡 (Hex: `#F1C40F`)
* **0 – 11 `YES` Points:** `Labis na mapanganib (High Hazard)` 🔴 (Hex: `#E74C3C`)

### 2. Urban Risk & Vulnerability Checklist (OLP - Sitio Level)
Tallies `YES` checks across 5 parameters (Land & Surface, Urbanization, Sociology, Structure Materials, Environmental):
* **0 – 19 `YES` Checks:** `Rating 3: Mildly Vulnerable` (Green)
* **20 – 39 `YES` Checks:** `Rating 4: Moderately Vulnerable` (Yellow)
* **40 – 70 `YES` Checks:** `Rating 5: Highly Vulnerable` (Red)

---

## 🛠️ Required Tasks for Antigravity Agent

Please inspect and update the Flutter Mobile Application codebase (`firesight_mobile`) to execute the following updates:

### Task 1: Update Data Models
1. **`lib/models/house_to_house_checklist_model.dart`**:
   * Implement getters `totalYesPoints`, `interpretation`, and `riskColorCode` following the exact 35-point threshold logic above.
2. **`lib/models/community_urban_checklist_model.dart`**:
   * Implement getters `totalYesCount`, `vulnerabilityRating` (3, 4, or 5), and `vulnerabilityLabel` following the OLP threshold rules.

### Task 2: Implement Inspection Order (IO) Consent & Refusal Flow
In **`lib/active_inspection_screen.dart`**:
* Before displaying the checklist, check `owner_consent_status`.
* Add an **"Owner Consent / Refusal"** pre-step modal or header:
  * If owner grants entry: allow inspector to proceed with filling out the checklist.
  * If owner refuses entry: show a mandatory dialog to enter `refusal_reason`. Update Supabase `inspections` table setting `owner_consent_status = 'refused'`, `overall_status = 'refused'`, and `approval_stage = 'flagged_for_fses_head'`.

### Task 3: Notice to Comply (NTC) Timer Integration
In **`lib/active_inspection_screen.dart`**:
* If any mandatory safety items fail, mark compliance as `Non-Compliant`.
* Automatically set `ntc_issued = true` and compute `ntc_expiry_date` (default: `DateTime.now().add(Duration(days: 14))`).
* Render an NTC countdown banner showing remaining days before re-inspection is required.

### Task 4: Enhance Interactive Risk & Infrastructure Map
In **`lib/fire_risk_mapping_screen.dart`**:
* Fetch data from `fire_risk_surveys`, `hydrants`, and `evacuation_centers`.
* Add toggle filters to display/hide:
  * 🔴/🟡/🟢 **Sitio Fire Risk Markers**
  * 💧 **Primewater Hydrants** (Blue = Operational, Red = Defective)
  * 🏫 **Evacuation Centers**

---

## 🎯 Verification Criteria
After code updates:
1. All models parse dynamic Supabase JSON correctly without type-casting exceptions.
2. The House-to-House and Urban Risk score interpretations match BFP threshold boundaries.
3. Refused inspections flag the FSES Head in Supabase without throwing null safety errors.
4. No compilation or lint errors exist in `flutter analyze`.