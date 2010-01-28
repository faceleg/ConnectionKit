//
//  KTDocWindowController.h
//  Marvel
//
//  Created by Dan Wood on 5/4/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "KSInspector.h"
#import "SVWebContentAreaController.h"


#define CUT_MENUITEM_TITLE					NSLocalizedString(@"Cut", "Cut MenuItem")
#define CUT_PAGE_MENUITEM_TITLE				NSLocalizedString(@"Cut Page", "Cut Page MenuItem")
#define CUT_PAGES_MENUITEM_TITLE			NSLocalizedString(@"Cut Pages", "Cut Pages MenuItem")

#define COPY_MENUITEM_TITLE					NSLocalizedString(@"Copy", "Copy MenuItem")
#define COPY_PAGE_MENUITEM_TITLE			NSLocalizedString(@"Copy Page", "Copy Page MenuItem")
#define COPY_PAGES_MENUITEM_TITLE			NSLocalizedString(@"Copy Pages", "Copy Pages MenuItem")

#define DELETE_COLLECTION_MENUITEM_TITLE	NSLocalizedString(@"Delete Collection", "Delete Collection MenuItem")
#define DELETE_PAGE_MENUITEM_TITLE			NSLocalizedString(@"Delete Page", "Delete Page MenuItem")
#define DELETE_PAGES_MENUITEM_TITLE			NSLocalizedString(@"Delete Pages", "Delete Pages MenuItem")


@class KSBorderlessWindow;
@class KSTextField, KSPopUpButton;
@class RoundedBox;
@class KTLinkSourceView;
@class SVPagesController;
@class SVSiteOutlineViewController;
@class KTPage;
@class KTCodeInjectionController;
@class SVDesignChooserWindowController;
@class BWAnchoredPopUpButton;

extern NSString *gInfoWindowAutoSaveName;


@interface KTDocWindowController : NSWindowController <KSInspection, SVWebContentAreaControllerDelegate>
{
	IBOutlet BWAnchoredPopUpButton 	*oActionPopup;
	//  TOOLBARS
   	NSMutableDictionary				*myToolbars;			// dict of document toolbars
	
	// WEBVIEW STUFF ....
	@public
	BOOL							myHasSavedVisibleRect;
	NSRect							myDocumentVisibleRect;
	
	
    NSMutableDictionary				*myContextElementInformation;
	IBOutlet KSBorderlessWindow		*oLinkPanel;
	IBOutlet RoundedBox				*oLinkControlsBox;
	IBOutlet NSTextField			*oLinkDestinationField;
	IBOutlet NSTextField			*oLinkLocalPageField;
	IBOutlet NSButton				*oLinkOpenInNewWindowSwitch;
	IBOutlet KTLinkSourceView		*oLinkView;
	
	BOOL							myIsLinkPanelClosing;
	
	IBOutlet KSBorderlessWindow		*oMessageWindow;
	IBOutlet NSTextField			*oMessageTextField;
	
	// oWebView selection
	NSPoint							myLastClickedPoint;
	NSRect							mySelectionRect;
	
@private
	SVWebContentAreaController  *_webContentAreaController;     // Weak ref
	SVSiteOutlineViewController *_siteOutlineViewController;
    SVPagesController           *_pagesController;
		
	// Code Injection
	KTCodeInjectionController	*myMasterCodeInjectionController;
	KTCodeInjectionController	*myPageCodeInjectionController;
    
    // Design Chooser
    SVDesignChooserWindowController *_designChooserWindowController;


	NSButton *myBuyNowButton;
}

#pragma mark View Controllers
@property(nonatomic, retain) IBOutlet SVSiteOutlineViewController *siteOutlineViewController;
@property(nonatomic, readonly) IBOutlet SVWebContentAreaController *webContentAreaController;
@property(nonatomic, retain) IBOutlet SVPagesController *pagesController;


#pragma mark Other
- (BOOL)addPagesViaDragToCollection:(KTPage *)aCollection atIndex:(int)anIndex draggingInfo:(id <NSDraggingInfo>)info;


//- (void)updateEditMenuItems;
- (void) updateBuyNow:(NSNotification *)aNotification;

// Actions
- (IBAction)toggleSmallPageIcons:(id)sender;

- (IBAction)windowHelp:(id)sender;

- (IBAction)addPage:(id)sender;             // your basic page
- (IBAction)addCollection:(id)sender;       // a collection. Uses [sender representedObject] for preset info
- (IBAction)addExternalLinkPage:(id)sender; // external link
- (IBAction)addRawTextPage:(id)sender;      // Raw HTML page
- (IBAction)addFilePage:(id)sender;         // uses open panel to select a file, then inserts
- (IBAction)group:(id)sender;

@property(retain) SVDesignChooserWindowController *designChooserWindowController;
- (IBAction)chooseDesign:(id)sender;
- (IBAction)showChooseDesignSheet:(id)sender;

- (IBAction)updateWebView:(id)sender;


#pragma mark Choose Dialog
- (NSOpenPanel *)makeChooseDialog;

@end


#pragma mark -


@interface KTDocWindowController ( Pasteboard )
- (BOOL)canPastePages;
- (BOOL)canPastePagelets;

- (IBAction)paste:(id)sender;
- (IBAction)pasteViaContextualMenu:(id)sender;
- (IBAction)pastePages:(id)sender;
- (IBAction)pastePagelets:(id)sender;

- (IBAction)duplicate:(id)sender;
- (IBAction)duplicateSelectedPages:(id)sender;
- (KTPage *)duplicatePage:(KTPage *)page;
- (IBAction)duplicatePagelets:(id)sender;
- (IBAction)duplicateViaContextualMenu:(id)sender;
@end


#pragma mark -


@interface KTDocWindowController ( Toolbar )

- (void)makeDocumentToolbar;
- (void)updateToolbar;

@end


#pragma mark -


extern NSString *KTSelectedDOMRangeKey;

@interface KTDocWindowController ( Accessors )

//- (DOMNode *)selectedDomNode;

- (NSRect)selectionRect;
- (void)setSelectionRect:(NSRect)aSelectionRect;

- (NSPoint)lastClickedPoint;
- (void)setLastClickedPoint:(NSPoint)aLastClickedPoint;

//- (id)selectedBlockItem;
//- (void)setSelectedBlockItem:(id)aSelectedBlockItem;

//- (NSString *)selectedBlockItemProperty;
//- (void)setSelectedBlockItemProperty:(NSString *)aSelectedBlockItemProperty;

- (NSMutableDictionary *)toolbars;
- (void)setToolbars:(NSMutableDictionary *)aToolbars;

@end


@interface KTDocWindowController (Publishing)

- (IBAction)publishSiteChanges:(id)sender;
- (IBAction)publishSiteAll:(id)sender;
- (IBAction)publishSiteFromToolbar:(NSToolbarItem *)sender;

- (IBAction)exportSite:(id)sender;
- (IBAction)exportSiteAgain:(id)sender;

- (IBAction)visitPublishedSite:(id)sender;
- (IBAction)visitPublishedPage:(id)sender;
- (IBAction)submitSiteToDirectory:(id)sender;

@end


