# Specification: Fade

## 1. Executive Summary
Fade is a specialized health utility for monitoring the progression and treatment of fungal skin infections. The app utilizes a 2D body-mapping interface to visualize rash sites and a logging system to correlate medication adherence with healing progress.

## 2. Core Data Models
The agent should implement the following using SwiftData:

**RashSite**
* `id`: UUID
* `location`: CGPoint (Normalized coordinates relative to the body outline)
* `bodySide`: Enum (Front, Back)
* `entries`: [RashEntry] (Relationship)

**RashEntry**
* `timestamp`: Date
* `diameterMM`: Double
* `photoURL`: String? (Optional for future expansion)

**TreatmentLog**
* `timestamp`: Date
* `medicationName`: String
* `wasCleaned`: Bool (Applied after shower)
* `notes`: String

## 3. Feature Breakdown

### Feature 1: The Interactive Body Map (Rash Tracker Tab)
* **Requirement**: A zoomable, pannable interface using a high-resolution SVG or vector-based outline of a human figure (Front and Back views).
* **Coordinate Mapping**: Use a ZStack where the body image is the base layer. User taps should convert local touch coordinates into a normalized 0.0 to 1.0 scale to ensure the dots stay in the correct anatomical position regardless of screen size.
* **Rash Placement**:
  * Long-press to drop a marker.
  * A "Size Slider" overlay appears to adjust the diameterMM.
  * The marker should be a semi-transparent red circle that scales based on the diameter input.
* **Zoom/Pan**: Implementation of MagnifyGesture and DragGesture to allow the user to inspect small areas (e.g., between toes or behind ears).

### Feature 2: Historical Timeline & Time-lapse
* **Requirement**: Visualizing the "vibe" of the healing process over time.
* **Date Scrubber**: A horizontal calendar picker at the bottom of the screen.
* **State Reconstruction**: When a date is selected, the map filters RashEntry data to show the size and location of all rashes as they existed on that specific date.
* **Time-lapse Mode**: An "Animate" button that cycles through dates (e.g., 0.5s per day), showing the red circles shrinking or growing based on the logged data.

### Feature 3: Treatment Logging (Treatment Tab)
* **Requirement**: A streamlined form for logging medication application.
* **Medication Library**: A List or Picker featuring common creams (Clotrimazole, Terbinafine, Ketoconazole) plus an "Add Custom" field that persists to the user's local library.
* **Application Workflow**:
  * Select medication.
  * Toggle "Applied after shower?" (Yes/No).
* **Cross-linking**: Upon saving a treatment, prompt the user: "Update rash sizes?" If yes, segue immediately to the Body Map for current-day measurements.

## 4. Technical Implementation Notes for Antigravity
* **Agent Instruction**: "Use SwiftUI for all views. Prioritize SwiftData for persistence. For the body map, use a Canvas or Path based approach to ensure smooth rendering of multiple rash sites. Ensure the UI follows Apple's Human Interface Guidelines for 'Health' category apps, using a clean, clinical aesthetic with Color.blue for treatments and Color.red for infection sites."
* **Key Views to Generate**:
  * `MainTabView`: Container for the two primary tabs.
  * `BodyMapView`: The custom coordinate-based interaction layer.
  * `RashDetailSheet`: A bottom sheet for editing diameter and adding notes.
  * `TreatmentFormView`: A standard SwiftUI Form for logging medication.

## 5. Success Criteria
* User can place a dot on the "Front" view and have it persist.
* User can slide a date picker and watch the dot size change based on historical logs.
* A "Summary" view shows the correlation between "Medication Applied" and "Total Rash Surface Area" decreasing.
