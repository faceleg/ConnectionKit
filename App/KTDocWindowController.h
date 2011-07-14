//
//  KTDocWindowController.h
//  Marvel
//
//  Created by Dan Wood on 5/4/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
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
@class KSTextField, KSFancySchmancyBindingsPopUpButton;
@class RoundedBox;
@class KTLinkSourceView;
@class SVPagesController;
@class SVSiteOutlineViewController;
@class KTPage, SVPagesTreeController;
@class KTCodeInjectionController;
@class SVDesignPickerController;
@class SVCommentsWindowController;
@class SVGoogleWindowController;
@class BWAnchoredPopUpButton;
@class MAAttachedWindow;

extern NSString *gInfoWindowAutoSaveName;


@interface KTDocWindowController : NSWindowController <KSInspection, SVWebContentAreaControllerDelegate>
{
	IBOutlet BWAnchoredPopUpButton 	*oActionPopup;
	//  TOOLBARS
   	NSMutableDictionary				*myToolbars;			// dict of document toolbars
	
	// WEBVIEW STUFF ....
  @public
	
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
    NSString    *_contentTitle;
    
	SVWebContentAreaController  *_webContentAreaController;     // Weak ref — why?
	SVSiteOutlineViewController *_siteOutlineViewController;
    SVPagesTreeController       *_pagesController;
		
	// Raw HTML
	KTHTMLEditorController      *_HTMLEditorController;
    KTCodeInjectionController	*myMasterCodeInjectionController;
	KTCodeInjectionController	*myPageCodeInjectionController;
    
    // Design Chooser
    SVDesignPickerController *_designChooserWindowController;
    
    // Comments
    SVCommentsWindowController *_commentsWindowController;
    
    // Google
    SVGoogleWindowController *_googleWindowController;
	
	NSMenuItem						*_rawHTMLMenuItem;		// like an outlet
	NSMenuItem						*_HTMLTextPageMenuItem;		// like an outlet

	MAAttachedWindow						*_designIdentityWindow;
	NSTextField								*_designIdentityTitle;
	NSImageView								*_designIdentityThumbnail;

}

#pragma mark Window Title
@property(nonatomic, copy) NSString *contentTitle;

#pragma mark View Controllers
@property(nonatomic, retain) IBOutlet SVSiteOutlineViewController *siteOutlineViewController;
@property(nonatomic, retain, readonly) IBOutlet SVWebContentAreaController *webContentAreaController;
@property(nonatomic, retain) IBOutlet SVPagesTreeController *pagesController;

#pragma mark Raw HTML
@property (nonatomic, retain) KTHTMLEditorController *HTMLEditorController;
@property(nonatomic, retain) NSMenuItem *rawHTMLMenuItem;
@property(nonatomic, retain) NSMenuItem *HTMLTextPageMenuItem;

@property(nonatomic, retain) SVCommentsWindowController *commentsWindowController;
@property(nonatomic, retain) SVGoogleWindowController *googleWindowController;

@property(nonatomic, retain, readonly) MAAttachedWindow *designIdentityWindow;

//- (void)updateEditMenuItems;
- (void) updateDocWindowLicenseStatus:(NSNotification *)aNotification;

// Actions
- (IBAction)toggleSmallPageIcons:(id)sender;

- (IBAction)windowHelp:(id)sender;

@property(nonatomic, retain) SVDesignPickerController *designChooserWindowController;
- (IBAction)chooseDesign:(id)sender;
- (IBAction)nextDesign:(id)sender;
- (IBAction)previousDesign:(id)sender;
- (IBAction)showChooseDesignSheet:(id)sender;

- (IBAction)editRawHTMLInSelectedBlock:(id)sender;
- (IBAction)showPageCodeInjection:(id)sender;
- (IBAction)showSiteCodeInjection:(id)sender;

- (IBAction)groupAsCollection:(id)sender;

- (IBAction)reload:(id)sender;


@end


#pragma mark -


@interface KTDocWindowController ( Toolbar )

- (void)makeDocumentToolbar;
- (void)updateToolbar;

@end


#pragma mark -


extern NSString *KTSelectedDOMRangeKey;

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


