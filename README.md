# <img width="80" alt="Untitled_Artwork 4" src="https://github.com/user-attachments/assets/22051cdd-29d6-43c0-a7db-37d3ae4f76c4" /> - Fade: Fungal Skin Infection Tracker

Fade is a specialized health utility application for iOS designed to help users meticulously monitor the progression and treatment of fungal skin infections. By combining a 2D body-mapping interface, a robust treatment logging system, and a comprehensive photo tracker, Fade provides actionable insights into healing progress and medication adherence.

## Core Features

### 1. Interactive Body Map (Rash Tracker)
- **Precise Localization:** A zoomable, pannable interface using high-resolution outlines of a human figure (Front and Back views).
- **Customizable Proportions:** User-adjustable waist width to ensure rash sizes are rendered with correct proportions for the individual's body type.
- **Fluid Interaction:** Continuous, fluid zooming and panning for precise placement of small rash sites.
- **Robust Management:** Long-press to drop a marker, adjust the diameter of the rash, and easily delete or edit individual rash entries. 

### 2. Advanced Rash Photo Tracking
- **Visual Progress:** Upload and track photos of specific rash sites over time.
- **Photo Alignment Tool:** Overlay new photos onto previous ones with transparency to ensure consistent angles and distances for accurate comparisons.
- **Height-Based Scaling:** Distort and stretch reference images vertically based on the user's height input (cm or inches) for an accurate visual representation proportional to their actual height.
- **Accurate Metadata:** Automatically extracts the original creation date and flash status directly from the photo's EXIF data, ensuring timeline accuracy.

### 3. Comprehensive Treatment Logging
- **Streamlined Workflow:** A fast, intuitive form to log medication applications.
- **Detailed Tracking:** Track crucial environmental factors, including whether the medication was applied after a shower and whether undergarments were changed.
- **Full Control:** Easily edit or delete existing treatment logs.

### 4. Summary Dashboard & Insights
- **Treatment Calendar:** A visual monthly grid calendar displaying historical medication usage. It features color-coding and icon indicators for shower status and undergarment changes.
- **Interactive Logs:** Tap any day on the calendar to view, edit, or delete the individual treatment logs for that date.
- **Actionable Insights:** Surfaces valuable trends from treatment logs, including pre-wash compliance percentages and 5 additional key data points offering insights into treatment adherence and skin health.

### 5. Configurable Notification System
- **Multiple Daily Reminders:** Schedule multiple daily treatment notifications to match complex medication routines.
- **Custom Schedules:** Configure specific, customized alerts for prescription pickups and rash photo upload requests.
- **Personalized Messaging:** Set custom start dates, frequencies, and messages for all notification types.

### 6. Privacy Protection
- **Secure Backgrounding:** Automatically applies a blur effect to the app screen when it transitions to the background (e.g., when opening the app switcher). This protects sensitive medical photos from being visible to onlookers.

## Technical Architecture

- **Frameworks:** SwiftUI for the entire UI, ensuring a clean, clinical aesthetic that complies with Apple's Human Interface Guidelines.
- **Persistence:** SwiftData for robust, local storage of all core data models.
- **Coordinate Mapping:** Uses normalized coordinate scaling (0.0 to 1.0) on the Body Map so rash markers stay in the correct anatomical position regardless of the device screen size.
