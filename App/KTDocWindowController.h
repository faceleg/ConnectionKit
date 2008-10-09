//
//  KTDocWindowController.h
//  Marvel
//
//  Created by Dan Wood on 5/4/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "KTController.h"


@class CIFilter;
@class KSBorderlessWindow;
@class KTInlineImageElement;
@class KSTextField, KSPopUpButton;
@class KTDesignPickerView;
@class RoundedBox;
@class RBSplitView;
@class RBSplitSubview;
@class NTBoxView;
@class RYZImagePopUpButton;
@class KTLinkSourceView;
@class KTPluginInspectorViewsManager;
@class KTDocWebViewController;
@class KTDocSiteOutlineController;
@class KTPage, KTPagelet;
@class KTCodeInjectionController;
@class KTAbstractElement;

extern NSString *gInfoWindowAutoSaveName;


@interface KTDocWindowController : NSWindowController <DOMEventListener, KTDocumentControllerChain>
{
    IBOutlet RBSplitView				*oSidebarSplitView;
    IBOutlet RBSplitView				*oDesignsSplitView;
	IBOutlet WebView					*oWebView;
	IBOutlet KTDocWebViewController		*webViewController;     // Weak ref
	IBOutlet KTDocSiteOutlineController	*siteOutlineController;
	IBOutlet NSObjectController			*oDocumentController;
		
	// Status bar below the webview
    IBOutlet NTBoxView				*oStatusBar;	// below web view
	IBOutlet NSImageView			*oSplitDragView;
	IBOutlet NSTextField			*oStatusBarField;	// URL pointed to, expand size to left of visible item(s) below
	
	// Detail panel for page titles & keywords
	IBOutlet NTBoxView							*oDetailPanel;
	IBOutlet NSTextField						*oPageNameField;
	IBOutlet NSTokenField						*oKeywordsField;
	IBOutlet KSPopUpButton	*oFileExtensionPopup;
	IBOutlet KSPopUpButton	*oCollectionIndexExtensionButton;
		
	
	// Uploading TO HOOK UP
	//	IBOutlet NSProgressIndicator    *oUploadStatusIndicator;	// upload status
	//	IBOutlet NSTextField			*oUploadStatusText;
	
    //  Navigation bar above the webview
	IBOutlet RBSplitSubview			*oDesignsSplitPane;
    IBOutlet KTDesignPickerView		*oDesignsView;
    IBOutlet NSButton				*oDesignBackButton;
    IBOutlet NSButton				*oDesignForwardButton;
    IBOutlet NSButton				*oDesignCloseButton;
	
    //  TOOLBARS
   	NSMutableDictionary				*myToolbars;			// dict of document toolbars
	RYZImagePopUpButton             *myAddPagePopUpButton;       // constructed via toolbar code
    RYZImagePopUpButton             *myAddPageletPopUpButton;       // constructed via toolbar code
    RYZImagePopUpButton             *myAddCollectionPopUpButton;    // constructed via toolbar code
	
	// WEBVIEW STUFF ....
	int								myPublishingMode;
	NSString						*myWebViewTitle;
	@public
	BOOL							myHasSavedVisibleRect;
	NSRect							myDocumentVisibleRect;
	
	// Site Outline
	KTDocSiteOutlineController	*mySiteOutlineController;
	
	// Editing
	BOOL							myRichText;
	BOOL							mySingleLine;
    
	NSMutableDictionary				*myContextElementInformation;
	IBOutlet KSBorderlessWindow		*oLinkPanel;
	IBOutlet RoundedBox				*oLinkControlsBox;
	IBOutlet NSTextField			*oLinkDestinationField;
	IBOutlet NSTextField			*oLinkLocalPageField;
	IBOutlet NSButton				*oLinkOpenInNewWindowSwitch;
	IBOutlet KTLinkSourceView		*oLinkView;
	
	BOOL							myIsLinkPanelClosing;
	BOOL							myIsCopying;
	
	IBOutlet KSBorderlessWindow		*oMessageWindow;
	IBOutlet NSTextField			*oMessageTextField;
	
	// selection
	KTInlineImageElement			*mySelectedInlineImageElement;
	KTPagelet						*mySelectedPagelet;
	
	// oWebView selection
	DOMRange						*mySelectedDOMRange;
	NSPoint							myLastClickedPoint;
	NSRect							mySelectionRect;
	
	// General purpose modal panel
	IBOutlet NSPanel				*oModalPanel;
	IBOutlet NSProgressIndicator	*oModalProgress;
	IBOutlet NSTextField			*oModalStatus;
	IBOutlet NSImageView			*oModalImage;
		
	NSLock							*myUpdateLock;
	BOOL myIsSuspendingUIUpdates;	// flag to see whether myUpdateLock isLocked
	
	NSObject						*myAddingPagesViaDragPseudoLock;
	
	// Code Injection
	KTCodeInjectionController	*myMasterCodeInjectionController;
	KTCodeInjectionController	*myPageCodeInjectionController;


	KTPluginInspectorViewsManager	*myPluginInspectorViewsManager;
	
	NSButton *myBuyNowButton;
    
    
    // Controller Chain
    NSMutableArray  *_childControllers;
}

#pragma mark Controller Chain
- (NSArray *)childControllers;
- (void)addChildController:(KTDocViewController *)controller;
- (void)removeChildController:(KTDocViewController *)controller;

- (KTDocSiteOutlineController *)siteOutlineController;
- (void)setSiteOutlineController:(KTDocSiteOutlineController *)controller;

- (KTDocWebViewController *)webViewController;
- (void)setWebViewController:(KTDocWebViewController *)controller;





- (BOOL)addPagesViaDragToCollection:(KTPage *)aCollection atIndex:(int)anIndex draggingInfo:(id <NSDraggingInfo>)info;

// Getters
- (BOOL) sidebarIsCollapsed;

// Other public functions

- (void)updatePopupButtonSizesSmall:(BOOL)aSmall;

- (void)setStatusField:(NSString *)string;
- (NSString *)status;

- (void)updateEditMenuItems;
- (void) updateBuyNow:(NSNotification *)aNotification;

// Actions

- (IBAction) windowHelp:(id)sender;
- (IBAction)addPage:(id)sender;
- (IBAction)addPagelet:(id)sender;
- (IBAction)addCollection:(id)sender;
- (IBAction)group:(id)sender;
- (IBAction)remove:(id)sender;

// Webview view type
- (IBAction)selectWebViewViewType:(id)sender;

- (IBAction)toggleDesignsShown:(id)sender;

- (IBAction)validateSource:(id)sender;

- (void)postSelectionAndUpdateNotificationsForItem:(id)aSelectableItem;
- (IBAction)reloadOutline:(id)sender;

- (void)insertPage:(KTPage *)aPage parent:(KTPage *)aCollection;
- (void)insertPagelet:(KTPagelet *)aPagelet toSelectedItem:(KTPage *)selectedItem;

// clean up at document close
- (void)selectionDealloc;
- (void)documentControllerDeallocSupport;

- (BOOL)isSuspendingUIUpdates;
- (void)suspendUIUpdates;
- (void)resumeUIUpdates;
- (void)showInfo:(BOOL)inShow;

// Plugin Inspector Views
- (KTPluginInspectorViewsManager *)pluginInspectorViewsManager;

@end

@interface KTDocWindowController ( SplitViews )
- (RBSplitView *)siteOutlineSplitView;
@end

@interface KTDocWindowController ( Pasteboard )
- (BOOL)canPastePages;
- (BOOL)canPastePagelets;

- (IBAction)cut:(id)sender;
- (IBAction)cutViaContextualMenu:(id)sender;
- (IBAction)cutPages:(id)sender;
- (IBAction)cutPagelets:(id)sender;

- (IBAction)copy:(id)sender;
- (IBAction)copyViaContextualMenu:(id)sender;
- (IBAction)copyPages:(id)sender;
- (IBAction)copyPagelets:(id)sender;

- (IBAction)paste:(id)sender;
- (IBAction)pasteViaContextualMenu:(id)sender;
- (IBAction)pastePages:(id)sender;
- (IBAction)pastePagelets:(id)sender;

- (IBAction)deleteViaContextualMenu:(id)sender;
- (IBAction)deletePages:(id)sender;
- (IBAction)deletePagelets:(id)sender;

- (IBAction)duplicate:(id)sender;
- (IBAction)duplicatePages:(id)sender;
- (IBAction)duplicatePagelets:(id)sender;
- (IBAction)duplicateViaContextualMenu:(id)sender;
@end

@interface KTDocWindowController ( Toolbar )

- (void)makeDocumentToolbar;
- (void)updateToolbar;

@end

@interface KTDocWindowController ( WebView )

- (IBAction)updateWebView:(id)sender;

- (NSWindow *)linkPanel;
- (void)closeLinkPanel;

- (void)linkPanelDidLoad;

- (IBAction)showLinkPanel:(id)sender;
- (IBAction)finishLinkPanel:(id)sender;
- (IBAction) clearLinkDestination:(id)sender;

- (IBAction)pasteLink:(id)sender;

- (KTAbstractElement *) selectableItemAtPoint:(NSPoint)aPoint itemID:(NSString **)outIDString;

- (void)webViewDidLoad;
- (void) webViewDeallocSupport;

- (id)itemForDOMNodeID:(NSString *)anID;

- (NSMutableDictionary *)contextElementInformation;
- (void)setContextElementInformation:(NSMutableDictionary *)aContextElementInformation;

- (BOOL)selectedDOMRangeIsEditable;
- (BOOL)selectedDOMRangeIsLinkableButNotRawHtmlAllowingEmpty:(BOOL)canBeEmpty;

- (BOOL)acceptDropOfURLsFromDraggingInfo:(id <NSDraggingInfo>)sender;

- (BOOL)isEditableElement:(DOMHTMLElement *)aDOMHTMLElement;
- (NSString *)propertyNameForDOMNodeID:(NSString *)anID;

- (KTPagelet *)pageletEnclosing:(DOMNode *)aDomNode;
- (DOMHTMLElement *)pageletElementEnclosing:(DOMNode *)aNode;

@end


extern NSString *kKTLocalLinkPboardType;
extern NSString *KTSelectedDOMRangeKey;

@interface KTDocWindowController ( Accessors )

- (KTInlineImageElement *)selectedInlineImageElement;
- (void)setSelectedInlineImageElement:(KTInlineImageElement *)anElement;

- (KTPage *)nearestParent:(NSManagedObjectContext *)aManagedObjectContext;

- (KTPagelet *)selectedPagelet;
- (void)setSelectedPagelet:(KTPagelet *)aSelectedPagelet;

- (int)publishingMode;
- (void)setPublishingMode:(int)aPublishingMode;

- (NSString *)webViewTitle;
- (void)setWebViewTitle:(NSString *)aWebViewTitle;

//- (DOMNode *)selectedDomNode;

- (DOMRange *)selectedDOMRange;
- (void)setSelectedDOMRange:(DOMRange *)aSelectedDOMRange;

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

- (RYZImagePopUpButton *)addPagePopUpButton;
- (void)setAddPagePopUpButton:(RYZImagePopUpButton *)anAddPagePopUpButton;

- (RYZImagePopUpButton *)addPageletPopUpButton;
- (void)setAddPageletPopUpButton:(RYZImagePopUpButton *)anAddPageletPopUpButton;

- (RYZImagePopUpButton *)addCollectionPopUpButton;
- (void)setAddCollectionPopUpButton:(RYZImagePopUpButton *)anAddCollectionPopUpButton;

- (NSObject *)addingPagesViaDragPseudoLock;
- (void)setAddingPagesViaDragPseudoLock:(NSObject *)anObject;

@end

/*! 
	General Purpose methods to display a document modal sheet
	
	- beginSheetWithStatus: displays an indeterminate progress bar
	- beginSheetWithStatus:minValue:maxValue: displays a determinate progress bar

*/
@interface KTDocWindowController (ModalOperation)

- (void)beginSheetWithStatus:(NSString *)status image:(NSImage *)image;
- (void)beginSheetWithStatus:(NSString *)status minValue:(double)min maxValue:(double)max image:(NSImage *)image;
- (void)updateSheetWithStatus:(NSString *)status progressValue:(double)value;
- (void)endSheet;
- (void)setSheetMinValue:(double)min maxValue:(double)max;

@end
