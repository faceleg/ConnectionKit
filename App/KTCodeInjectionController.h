//
//  KTCodeInjectionController.h
//  Marvel
//
//  Created by Terrence Talbot on 4/5/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"


@class SVPagesController, BWSplitView, KSPlaceholderTextView;
@protocol KSCollectionController;

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@protocol NSSplitViewDelegate <NSObject> @end
#endif

@interface KTCodeInjectionController : KSSingletonWindowController <NSSplitViewDelegate>
{
	IBOutlet NSTextField	*oCodeInjectionDescriptionLabel;
	IBOutlet NSTabView		*oTabView;
	
	IBOutlet KSPlaceholderTextView		*oPreludeTextView;
	
	IBOutlet BWSplitView				*oHeadSplitView;
	IBOutlet KSPlaceholderTextView		*oEarlyHeadTextView;
	IBOutlet KSPlaceholderTextView		*oHeadTextView;
	
	IBOutlet BWSplitView				*oBodySplitView;
	IBOutlet KSPlaceholderTextView		*oBodyStartTextView;
	IBOutlet KSPlaceholderTextView		*oBodyEndTextView;
	IBOutlet NSTextField				*oBodyTagTextField;

	IBOutlet KSPlaceholderTextView		*oCSSTextView;

@private
	id <KSCollectionController> _pagesController;	// weak ref
	BOOL                        _isMaster;
	
	NSTimer	*myTextEditingTimer;
}

- (id)initWithPagesController:(id <KSCollectionController>)controller
                       master:(BOOL)isMaster;

- (BOOL)isMaster;

- (IBAction)showHelp:(id)sender;

@end
