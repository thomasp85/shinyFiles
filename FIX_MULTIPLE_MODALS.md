# Fix for Multiple shinyDirChoose Modal Issue

## Problem Description

When using multiple `shinyDirChoose` buttons with different IDs in an R Shiny app, the modal where directories are selected does not close after clicking "Select". This issue occurs because:

1. Each `shinyDirChoose` button creates its own modal with a unique ID
2. The JavaScript event handlers use generic selectors (`.sF-modalContainer`) that can match multiple modals
3. When multiple modals exist, the event handlers may target the wrong modal or cause conflicts

## Root Cause

The issue was in the JavaScript code in `inst/www/shinyFiles.js`:

1. **No cleanup of existing modals**: When creating a new modal, existing modals for the same button were not cleaned up
2. **Generic selectors in event handlers**: The keydown handler and backdrop click handler used generic selectors that could match multiple modals
3. **Event handler conflicts**: Multiple modals could interfere with each other's event handling

## Solution

The fix includes several changes to `inst/www/shinyFiles.js`:

### 1. Modal Cleanup on Creation

Added cleanup of existing modals when creating new ones in all three modal creation functions:

```javascript
// Clean up any existing modals for this button
var existingModal = $(button).data('modal');
if (existingModal) {
  removeFileChooser(button, existingModal);
}
```

This ensures that each button only has one active modal at a time.

### 2. Fixed Keydown Handler

Changed the keydown handler to work with multiple modals by finding the currently visible modal:

```javascript
// Before (problematic)
if ($(".sF-modalContainer").is(":visible")) {
  var modalButton = $($(".sF-modalContainer").data('button'));
  // ...
}

// After (fixed)
var visibleModal = $(".sF-modalContainer:visible").first();
if (visibleModal.length > 0) {
  var modalButton = visibleModal.data('button');
  // ...
}
```

### 3. Fixed Backdrop Click Handler

Updated the backdrop click handler to work with the specific modal that was clicked:

```javascript
// Before (problematic)
if (!$(e.target).closest('.modal-content').length > 0 && $("#sF-cancelButton").is(":visible")) {
  $("#sF-cancelButton").click();
}

// After (fixed)
if (!$(e.target).closest('.modal-content').length > 0 && $(this).find("#sF-cancelButton").is(":visible")) {
  $(this).find("#sF-cancelButton").click();
}
```

### 4. Fixed Escape Key Handler

Updated the escape key handler to work with the currently visible modal:

```javascript
// Before (problematic)
if ($("#sF-cancelButton").is(":visible") && !$("div.sF-newDir").hasClass("open")) {
  $("#sF-cancelButton").click();
}

// After (fixed)
var visibleModal = $(".sF-modalContainer:visible").first();
if (visibleModal.length > 0 && visibleModal.find("#sF-cancelButton").is(":visible") && !visibleModal.find("div.sF-newDir").hasClass("open")) {
  visibleModal.find("#sF-cancelButton").click();
}
```

## Testing

A test app (`test_multiple_dirs.R`) has been created to verify the fix works correctly. The test app includes three `shinyDirChoose` buttons to ensure that:

1. Each modal opens and closes correctly
2. The "Select" button properly closes the modal
3. Multiple modals don't interfere with each other
4. Keyboard shortcuts (Enter, Escape) work correctly

## Files Modified

- `inst/www/shinyFiles.js`: Fixed modal creation and event handlers
- `test_multiple_dirs.R`: Test app to verify the fix
- `FIX_MULTIPLE_MODALS.md`: This documentation

## Impact

This fix resolves the issue where modals don't close after clicking "Select" when using multiple `shinyDirChoose` buttons. The fix is backward compatible and doesn't affect single modal usage.
