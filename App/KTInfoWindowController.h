//
//  KTInfoWindowController.h
//  Marvel
//
//  Created by Dan Wood on 5/4/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum { SEGMENT_NONE = -1, SEGMENT_SITE, SEGMENT_PAGE, SEGMENT_SELECTION };

@class KTStackView, KTImageView, KTPathInfoField;
@class KTSmallDatePicker;
@class KTDocument;
@class KTPagelet;
@class KTPage;

@interface KTInfoWindowController : NSWindowController {

	IBOutlet NSPanel			*oPanel;
	IBOutlet NSObjectController	*oInfoWindowController;
	IBOutlet NSController		*oPageController;

	IBOutlet KTStackView		*oStackView;	// top level container, installed in window

	IBOutlet NSTabView			*oSiteTabView;
	
	// These are views that get stacked up inside
	IBOutlet NSView				*oPageletGeneralView;
	IBOutlet NSView				*oNothingView;
	IBOutlet NSView				*oCollectionView;
	IBOutlet NSView				*oDividerView;
	IBOutlet NSView				*oPageDetailsHeaderView;
	IBOutlet NSView				*oPageletDetailsHeaderView;
	IBOutlet NSView				*oPageView;
	IBOutlet NSView				*oCustomIndexView;
	IBOutlet NSView				*oSegmentsView;
	IBOutlet NSView				*oSiteView;
	IBOutlet NSView				*oProRequiredView;
	IBOutlet NSView				*oHelpBottomView;

	IBOutlet NSView				*oFillerView;		// temporary, I hope ... later, we'll resize window
	
	// Site Controls
	IBOutlet NSSegmentedControl	*oTabSegmentedControl;
	IBOutlet KTImageView		*oThumbImageView;
	IBOutlet KTImageView		*oFaviconImageView;
	IBOutlet KTPathInfoField	*oLogoPathInfoField;
	IBOutlet KTPathInfoField	*oBannerPathInfoField;
	
	// Page Controls
	IBOutlet NSTextField		*oPageMenuTitleField;
	IBOutlet NSView				*oSmallDatePickerPlaceholderView;
    KTSmallDatePicker           *mySmallDatePicker; // takes over for oSmallDatePickerPlaceholderView
	

	IBOutlet NSPopUpButton			*oIndexPopup;
	IBOutlet NSPopUpButton			*oSortPopup;
	IBOutlet NSPopUpButton			*oCollectionStylePopup;
	BOOL							myIgnoreCollectionStyleChanges;

	IBOutlet NSPopUpButton			*oLanguagePopup;
	IBOutlet NSTextField			*oLanguageCodeField;
	
	IBOutlet NSTextView				*oGoogleVerificationExplanationTextView;
	IBOutlet NSTextView				*oGoogleAnalyticsExplanationTextView;

	int mySelectedSegmentIndex;
	
	NSView						*mySelectionInspectorView;
	NSView						*myPageInspectorView;
	id							myCurrentSelection;
	KTDocument					*myAssociatedDocument;
	KTPagelet					*mySelectedPagelet;
	KTPage						*mySelectedLevel;
		
	int mySelectedPageletPosition;
	
	int	myCustomFileExtension;
	int myPageletPositionNumber;
	
	BOOL	myDisclosedPreset;
	BOOL	myPreventWindowAnimation;
}

+ (KTInfoWindowController *)sharedInfoWindowController;
+ (KTInfoWindowController *)sharedInfoWindowControllerWithoutLoading;

- (KTDocument *)associatedDocument;
- (void)setAssociatedDocument:(KTDocument *)aDocument;

- (void)putContentInWindow;

- (int)customFileExtension;
- (void)setCustomFileExtension:(int)aCustomFileExtension;

- (id)currentSelection;

- (KTPage *)selectedLevel;
- (void)setSelectedLevel:(KTPage *)aSelectedLevel;

- (KTPagelet *)selectedPagelet;
- (void)setSelectedPagelet:(KTPagelet *)aSelectedPagelet;


/*! empty out the inspector */
- (void)clearAll;
- (void)clearObjectControllers;

- (void)setupViewStackFor:(id)selectedItem selectLevel:(BOOL)aWantLevel;

- (IBAction)chooseBannerImagePath:(id)sender;
- (IBAction)clearBannerImage:(id)sender;
- (IBAction)chooseLogoImagePath:(id)sender;
- (IBAction)clearLogoImage:(id)sender;
- (IBAction)chooseFaviconPath:(id)sender;
- (IBAction)clearFavicon:(id)sender;

- (IBAction)choosePageThumbnail:(id)sender;
- (IBAction)resetPageThumbnail:(id)sender;

- (IBAction)windowHelp:(id)sender;
- (IBAction)openHaloscan:(id)sender;
- (IBAction)languageChosen:(id)sender;

- (IBAction)movePageletUp:(id)sender;
- (IBAction)movePageletDown:(id)sender;

/*! returns undoManager of associatedDocument */
- (NSUndoManager *)undoManager;

@end
