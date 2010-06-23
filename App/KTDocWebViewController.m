//
//  KTDocWebViewController.m
//  Marvel
//
//  Created by Mike on 13/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTDocWebViewController.h"
#import "KTDocWebViewController+Private.h"
#import "KTAsyncOffscreenWebViewController.h"

#import "Debug.h"
#import "KT.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocSiteOutlineController.h"
#import "KTHelper.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "KTWebViewComponent.h"
#import "KTDocument.h"
#import "KTSite.h"

#import "KTImageScalingURLProtocol.h"
#import "KTMediaManager.h"
#import "KTScaledImageContainer.h"
#import "KTMediaFile+Internal.h"

#import "NSImage+Karelia.h"
#import "CIImage+Karelia.h"
#import "KSSilencingConfirmSheet.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSTextView+KTExtensions.h"
#import "WebView+Karelia.h"
#import "NSView+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "NSURL+Karelia.h"

#import <QuartzCore/QuartzCore.h>



@interface WebView (WebKitSecretsIKnow)
- (void)_setCatchesDelegateExceptions:(BOOL)f;
@end


#pragma mark -


@implementation KTDocWebViewController

#pragma mark -
#pragma mark Initialization

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObject:@"currentTextEditingBlock"]
		triggerChangeNotificationsForDependentKey:@"webViewIsEditing"];
	
	[self setKeys:[NSArray arrayWithObject:@"viewType"]
		triggerChangeNotificationsForDependentKey:@"hideWebView"];
}

- (id)init
{
	[super init];
	
	myInlineImageNodes = [[NSMutableDictionary alloc] init];
	myInlineImageElements = [[NSMutableDictionary alloc] init];
	
	[self init_webViewLoading];
	
	return self;
}

- (void)awakeFromNib
{
	// Register for requests to change the current page's design
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(designChangedNeedWebViewUpdate:)
												 name:kKTDesignChangedNotification
											   object:[self document]];
}

#pragma mark -
#pragma mark Dealloc

- (void)dealloc
{
	[self dealloc_webViewLoading];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self setWebView:nil];
    [self setElementWaitingForFragmentLoad:nil];
    [self setAsyncOffscreenWebViewController:nil];
	[self setSavedPageletStyle:nil];
	[self setAnimationCoverWindow:nil];
    [self setAnimationTimer:nil];
    [self setTransitionFilter:nil];
    
	[self setMainWebViewComponent:nil];
	
	// Editing
	[myMidEditHTML release];
	[myTextEditingBlock release];
	[myUndoManagerProxy release];
	[myInlineImageNodes release];
	[myInlineImageElements release];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[super dealloc];
}

#pragma mark -
#pragma mark View

- (void)setView:(NSView *)aView
{
    // The view SHOULD be a WebView or nil unless someone is abusing the property
    OBPRECONDITION(!aView || [aView isKindOfClass:[WebView class]]);
    [self setWebView:(WebView *)aView];
}

- (WebView *)webView
{
    return (WebView *)[self view];
}

- (void)setWebView:(WebView *)aWebView
{
	// Clear old delegates to avoid memory bugs
    WebView *oldWebView = [self webView];
    [oldWebView setEditingDelegate:nil];
    [oldWebView setFrameLoadDelegate:nil];
    [oldWebView setPolicyDelegate:nil];
    [oldWebView setResourceLoadDelegate:nil];
    [oldWebView setUIDelegate:nil];
    
    
    // Store the view
    [super setView:aWebView];
    
    
    // Web Preferences
    WebView *newWebView = [self webView];
	[newWebView setPreferencesIdentifier:@"SandvoxSitePreview"];
    [[newWebView preferences] setAutosaves:NO];
    
    
    // Setup new delegation
    [newWebView setEditingDelegate:self];
    [newWebView setUIDelegate:[self windowController]];
    
    
    // By default, WebKit catches and logs any exceptions in delegate methods.
    // For beta builds though, we want any exceptions to be reported back to Karelia via our feedback reporter
#ifndef VARIANT_RELEASE
    if ([aWebView respondsToSelector:@selector(_setCatchesDelegateExceptions:)])
    {
        [aWebView _setCatchesDelegateExceptions:NO];
    }
#endif
}

#pragma mark -
#pragma mark Controller Chain

- (void)setDocument:(KTDocument *)document
{
    if ([self document])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSManagedObjectContextObjectsDidChangeNotification
                                                      object:[[self document] managedObjectContext]];
    }
    
    [super setDocument:document];
    [self setWebViewNeedsReload:NO];
    
    if ([self document])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(documentDidChange:)
                                                     name:NSManagedObjectContextObjectsDidChangeNotification
                                                   object:[[self document] managedObjectContext]];
    }
}

/*  At present, the window controller is the UI delegate.
 */
- (void)setWindowController:(KTDocWindowController *)aWindowController
{
    [super setWindowController:aWindowController];
    [[self webView] setUIDelegate:[self windowController]];
}

#pragma mark -
#pragma mark Accessors

- (DOMHTMLElement *)elementWaitingForFragmentLoad
{
    return myElementWaitingForFragmentLoad; 
}
- (void)setElementWaitingForFragmentLoad:(DOMHTMLElement *)anElementWaitingForFragmentLoad
{
    [anElementWaitingForFragmentLoad retain];
    [myElementWaitingForFragmentLoad release];
    myElementWaitingForFragmentLoad = anElementWaitingForFragmentLoad;
}


- (KTAsyncOffscreenWebViewController *)asyncOffscreenWebViewController
{
	if (nil == myAsyncOffscreenWebViewController)
	{
		myAsyncOffscreenWebViewController = [[KTAsyncOffscreenWebViewController alloc] init];
	}
    return myAsyncOffscreenWebViewController; 
}
- (void)setAsyncOffscreenWebViewController:(KTAsyncOffscreenWebViewController *)anAsyncOffscreenWebViewController
{
    [anAsyncOffscreenWebViewController retain];
    [myAsyncOffscreenWebViewController release];
    myAsyncOffscreenWebViewController = anAsyncOffscreenWebViewController;
}


- (NSTextView *)sourceCodeTextView { return oSourceTextView; }

- (BOOL)isWebViewLoading { return myWebViewIsLoading; }

- (void)setWebViewLoading:(BOOL)isLoading { myWebViewIsLoading = isLoading; }

- (NSString *)savedPageletStyle { return mySavedPageletStyle; }

- (void)setSavedPageletStyle:(NSString *)aSavedPageletStyle
{
	[aSavedPageletStyle retain];
	[mySavedPageletStyle release];
	mySavedPageletStyle = aSavedPageletStyle;
}


- (NSWindow *)animationCoverWindow
{
    return myAnimationCoverWindow;
}

- (void)setAnimationCoverWindow:(NSWindow *)anAnimationCoverWindow
{
    [anAnimationCoverWindow retain];
    [myAnimationCoverWindow release];
    myAnimationCoverWindow = anAnimationCoverWindow;
}

- (NSTimer *)animationTimer { return myAnimationTimer; }

- (void)setAnimationTimer:(NSTimer *)anAnimationTimer
{
	[anAnimationTimer retain];
	
	[myAnimationTimer invalidate];		// invalidate the timer before releasing; needed?
	[myAnimationTimer release];
	
	myAnimationTimer = anAnimationTimer;
}

- (CIFilter *)transitionFilter { return myTransitionFilter; }

- (void)setTransitionFilter:(CIFilter *)aTransitionFilter
{
    [aTransitionFilter retain];
    [myTransitionFilter release];
    myTransitionFilter = aTransitionFilter;
}

- (NSTimeInterval)baseTime { return myBaseTime; }

- (void)setBaseTime:(NSTimeInterval)aBaseTime { myBaseTime = aBaseTime; }

- (NSTimeInterval)totalAnimationTime { return myTotalAnimationTime; }

- (void)setTotalAnimationTime:(NSTimeInterval)aTotalAnimationTime { myTotalAnimationTime = aTotalAnimationTime; }

#pragma mark -
#pragma mark View Type

- (KTWebViewViewType)viewType { return myViewType; }

- (void)setViewType:(KTWebViewViewType)aViewType;
{
	// When switching away from standard view, make sure any pending changes are comitted
	KTWebViewViewType oldView = [self viewType];
	if (oldView == KTStandardWebView || oldView == KTWithoutStylesView)
	{
		[self commitEditing];
	}
	
	// Store the new value
    myViewType = aViewType;
	
	
	// If the source code view is visible now, it will require loading
	if ([self hideWebView])
	{
		[self loadPageIntoSourceCodeTextView:[self page]];
	}
	else if (aViewType != KTHTMLValidationView)
	{
		[self reloadWebView];
	}
}

/*	The sender's tag should correspond to a view type. If the user clicks the currently selected option for the second time,
 *	we revert back to standard preview.
 */
- (IBAction)selectWebViewViewType:(id)sender;
{
	KTWebViewViewType viewType = [sender tag];
	if (viewType == [self viewType])
	{
		viewType = KTStandardWebView;
	}
	
	[self setViewType:viewType];
}

- (BOOL)hideWebView
{
	switch ([self viewType])
	{
		case KTSourceCodeView:
		case KTPreviewSourceCodeView:
		case KTDOMSourceView:
		case KTRSSSourceView:
			return YES;
			break;
		
		case KTStandardWebView: 
		case KTWithoutStylesView:
		case KTHTMLValidationView:
		case KTRSSView:	
		default:
			return NO;
	}
}

#pragma mark -
#pragma mark Text Size

/*  WebKit provides its own version of all these methods. We define them here to catch when
 *  the WebView is not in the responder chain.
 */

- (IBAction)makeTextLarger:(id)sender
{
	[[self webView] makeTextLarger:sender];
}

- (IBAction)makeTextSmaller:(id)sender
{
	[[self webView] makeTextSmaller:sender];
}

- (IBAction)makeTextStandardSize:(id)sender
{
	[[self webView] setTextSizeMultiplier:1.0];
}

#pragma mark -
#pragma mark Update / Animation

- (void)updateWebViewAnimated
{
	// Clear things just in case
	[self setAnimationTimer:nil];
	[self setTransitionFilter:nil];
	if ([self animationCoverWindow])
	{
		[[[self webView] window] removeChildWindow:[self animationCoverWindow]];
		[self setAnimationCoverWindow:nil];
	}
	// (stop loading just in case it was already loading, to handle multiple clicks.
	[[[self webView] mainFrame] stopLoading];

	// First figure out if we can animate
	CIFilter *filter = nil;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *filterName = [defaults objectForKey:@"CIFilterNameForAnimation"];		
	
	if (nil != filterName)
	{
		filter = [CIFilter filterWithName:filterName];
	}
	
	
	// ANIMATION ONLY WORKS IF WE HAVE FAST CORE IMAGE ... OTHERWISE THERE'S NO POINT!
	
	if ([defaults boolForKey:@"DoAnimations"] && [KTAppDelegate fastEnoughProcessor] && [KTAppDelegate coreImageAccelerated]
		&& nil != filter
		&& ([[defaults objectForKey:@"AnimationTime"] floatValue] > 0.0))
	{
		[self setTransitionFilter:filter];
		
		NSView *theView = [self webView];
		
		NSRect r= [theView bounds];
		// DON'T USE THE TIGER-API TECHNIQUE -- IT DOESN'T CAPTURE ANTI-ALIASED TEXT QUITE RIGHT.
		// NSBitmapImageRep *bitmap = [oWebView bitmapImageRepForCachingDisplayInRect:r];
		// OLD TECHNIQUE [oWebView cacheDisplayInRect:r toBitmapImageRep:bitmap];
		[theView lockFocus];
		NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:r] autorelease];
		[theView unlockFocus];
		
		NSRect subWindowRect = [theView convertRect:r toView:nil];
		subWindowRect.origin = [[[self webView] window] convertBaseToScreen:subWindowRect.origin];
		
		NSWindow *childWindow = [[[NSWindow alloc] initWithContentRect:subWindowRect
															 styleMask:NSBorderlessWindowMask
															   backing:NSBackingStoreBuffered
																 defer:YES] autorelease];
		NSImageView *imageView = [[[NSImageView alloc] initWithFrame:r] autorelease];
		NSImage *image = [NSImage imageWithBitmap:bitmap];
		
//	FIXME:	I reported to Apple: background images are slightly screwy in the snapshot.
		//	[[image TIFFRepresentation] writeToFile:[@"~/Desktop/START.tiff" stringByExpandingTildeInPath] atomically:NO];
		
		[imageView setImage:image];
		[childWindow setContentView:imageView];
		[[[self webView] window] addChildWindow:childWindow ordered:NSWindowAbove];
		[self setAnimationCoverWindow:childWindow];
		
		// Kick off animation after a short delay to get at least partial webview loaded.
		// If the webview finishes loading before that, it will cancel this.
		// First make sure it's not already queued up (in case of multiple clicks)
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startAnimation:) object:nil];
		[self performSelector:@selector(startAnimation:) withObject:nil afterDelay:0.01];
	}
	
	// make sure we're seeing webview and styles
	[self setViewType:KTStandardWebView];
	
	
	// Animation won't really start until all the internal stuff is done anyhow, so it's just
	// a matter of painting to screen.	 So we started animation delayed almost immediately.
}





- (void)designChangedNeedWebViewUpdate:(NSNotification *)aNotification
{
	if ( (nil != [aNotification userInfo]) && (YES == [[[aNotification userInfo] valueForKey:@"animate"] boolValue]) )
	{
		myAnimateStartingPoint = NSPointFromString([[aNotification userInfo] valueForKey:@"mouse"]);
		
		if ([self webViewIsEditing])
		{
			// Act as if we ended editing, so changes get saved
			//(void) [self webView:[self webView] shouldEndEditingInDOMRange:nil];	// manually call this to force some stuff that's skipped if we end this way
			[self commitEditing];
			
			// DON'T suspend
			//[self setSuspendNextWebViewUpdate:DONT_SUSPEND];
		}

		
		[self updateWebViewAnimated];
	}
}


#pragma mark -
#pragma mark WebFrameLoadDelegate Methods

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
	// Only report feedback for the main frame.
	if (frame == [sender mainFrame]){
		[self setWebViewLoading:YES];
		// Reset resource status variables .... 
		// we check all subresources loading per suggestion from  Mike Fischer
		// webkit-sdk message of March 31 2007, "Re: How to tell is a Web page is fully loaded"
		myResourceCount = 0;
		myResourceCompletedCount = 0;
		myResourceFailedCount = 0;
	}
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if (frame == [[self webView] mainFrame])
	{
		if ([self animationCoverWindow])	// Are we working on a transition animation?
		{
			if (nil== [self animationTimer] || ![[self animationTimer] isValid])	// not already started by the delayed perform?
			{
				[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startAnimation:) object:nil];
				[self startAnimation:nil];
			}
			else	// Animation already started, so just "fix" the final image mid-animate
			{
				NSRect r = [[self webView] bounds];
				NSBitmapImageRep *bitmap = [[self webView] bitmapImageRepForCachingDisplayInRect:r];
				[[self webView] cacheDisplayInRect:r toBitmapImageRep:bitmap];
				// DON'T USE THIS "OLD" TECHNIQUE -- IT DOESN'T SEEM TO CAPTURE THE *NEW* IMAGE!
				//[oWebView lockFocus];
				//NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:r];
				//[oWebView unlockFocus];
				
				CIImage *destImage = [[[CIImage alloc] initWithBitmapImageRep:bitmap] autorelease];
				[[self transitionFilter] setValue:destImage forKey:@"inputTargetImage"];
			}
		}
		
		
		
		// Restore scroll position
		
		NSScrollView *scrollView = [[self webView] mainScrollView];
		if (scrollView && [self windowController] && ([self windowController]->myHasSavedVisibleRect))
        {
			[(NSView *)[scrollView documentView] scrollRectToVisible:([self windowController]->myDocumentVisibleRect)];
			([self windowController]->myHasSavedVisibleRect) = NO;
		}
		
		// Make sure webview is visible now.
/////		[oSourceScrollView setHidden:YES];
////		[oWebView setHidden:NO];
		
//		[[[self document] updateLock] tryLock]; // either it locks or it doesn't
//		[[[self document] updateLock] unlock]; // in either case, we need to unlock it

		///handling paste event so we can intercept
		// DOESN'T SEEM TO WORK YET?  [[frame DOMDocument] addEventListener:@"onbeforepaste" :self :YES];
	
		// wait five seconds for sub-resources to load; otherwise give up
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(forceWebViewLoadingDone) object:nil];
		[self performSelector:@selector(forceWebViewLoadingDone) withObject:nil afterDelay:5.0];
	}
}

- (void)forceWebViewLoadingDone
{
	OFF((@"Giving up on subresources loading; marking myWebViewIsLoading = NO"));
	[self setWebViewLoading:NO];
}

#pragma mark -
#pragma mark WebResourceLoadDelegate Methods

- (NSURLRequest *)webView:(WebView *)sender
				 resource:(id)identifier
		  willSendRequest:(NSURLRequest *)request
		 redirectResponse:(NSURLResponse *)redirectResponse
		   fromDataSource:(WebDataSource *)dataSource
{
	NSURL *requestURL = [request URL];
	NSMutableURLRequest *result = [[request mutableCopy] autorelease];
	
    
	if ([requestURL isEqual:[request mainDocumentURL]])
    {
        // Force webkit to reload subresources all the time. BUGSID:35835
        [result setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    }
    else if ([requestURL hasNetworkLocation] &&
        ![[NSUserDefaults standardUserDefaults] boolForKey:kSVLiveDataFeedsKey] &&
        ![[requestURL scheme] isEqualToString:@"svxmedia"] &&
		![[requestURL scheme] isEqualToString:KTImageScalingURLProtocolScheme])
	{
		LOG((@"webView:resource:willSendRequest:%@ ....Forcing to ONLY load from any cache", requestURL));
		
		[result setCachePolicy:NSURLRequestReturnCacheDataDontLoad];	// don't load, but return cached value
		return result;
	}
	else if (requestURL)
	{
		NSString *relativePath = [requestURL relativePath];
		if ([[requestURL scheme] isEqualToString:@"svxmedia"])
		{
			// Find the media container from the URL
			NSString *requestURLString = [requestURL absoluteString];
			NSString *mediaIdentifier = [requestURLString lastPathComponent];
			
			KTMediaContainer *mediaContainer = [[[self document] mediaManager] mediaContainerWithIdentifier:mediaIdentifier];
			
			if ([mediaContainer isKindOfClass:[KTScaledImageContainer class]])
			{
				KTMediaFile *mediaFile = [mediaContainer sourceMediaFile];
				NSURL *URL = [mediaFile URLForImageScalingProperties:[(KTScaledImageContainer *)mediaContainer latestProperties]];
				[result setURL:[URL absoluteURL]];	// WebKit can't seem to handle a relative URL here.
				
				NSString *path = [mediaFile currentPath];
				if (path) [result setScaledImageSourceURL:[NSURL fileURLWithPath:path]];
			}
			else
			{
				// Redirect to the source media
				KTMediaFile *mediaFile = [mediaContainer file];
				NSString *path = [mediaFile currentPath];
				if (path) [result setURL:[NSURL fileURLWithPath:path]];
			}
			
			return result;
		}
		else if ([[[result URL] scheme] isEqualToString:KTImageScalingURLProtocolScheme])
		{
			// To work right, the URL request needs to be modified to point to the media on disk
			NSString *mediaID = [[result URL] lastPathComponent];
			KTMediaFile *media = [[[[self windowController] document] mediaManager] mediaFileWithIdentifier:mediaID];
			NSString *path = [media currentPath];
			if (path)
			{
				[result setScaledImageSourceURL:[NSURL fileURLWithPath:path]];
			}
		}
		else
		{
			OFF((@"requestURL = %@", requestURL));
		}
		
		//	Handle pointers to the resources folder. e.g. "sandvox_Aqua/main.css"
		KTDesign *design = [[[self page] master] design];
		if ([relativePath hasPrefix:[NSString stringWithFormat:@"/%@", [design remotePath]]])
		{
			NSURL *URL = [NSURL fileURLWithPath:[[design bundle] pathForResource:@"main" ofType:@"css"]];
			[result setURL:URL];
			return result;
		}
	}
	
	// If not a Media URL
	return result;
}

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource
{
	return [NSNumber numberWithInt:myResourceCount++];
}

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource
{
	myResourceCompletedCount++;

	// Check if we are done now
	if ( 0 == myResourceCount - (myResourceCompletedCount + myResourceFailedCount) )
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(forceWebViewLoadingDone) object:nil];
		OFF((@"subresources done loading; marking myWebViewIsLoading = NO"));
		[self setWebViewLoading:NO];
	}
}

- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource
{
	if (! (([[error domain] isEqualToString:WebKitErrorDomain])
		  && ([error code] == WebKitErrorFrameLoadInterruptedByPolicyChange)))
	{
		myResourceFailedCount++;
	}
	
	// Check if we are done now
	if ( 0 == myResourceCount - (myResourceCompletedCount + myResourceFailedCount) )
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(forceWebViewLoadingDone) object:nil];
		OFF((@"subresources done loading (last one was an error); marking myWebViewIsLoading = NO"));
		[self setWebViewLoading:NO];
	}
}

#pragma mark -
#pragma mark Other


@end
