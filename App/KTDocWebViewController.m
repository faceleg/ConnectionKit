//
//  KTDocWebViewController.m
//  Marvel
//
//  Created by Mike on 13/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
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
#import "KTAppDelegate.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"

#import "KTMediaManager.h"
#import "KTMediaContainer.h"
#import "KTMediaFile.h"

#import "NSImage+Karelia.h"
#import "CIImage+Karelia.h"
#import "KSSilencingConfirmSheet.h"
#import "NSString+Karelia.h"
#import "NSString-Utilities.h"
#import "NSTextView+KTExtensions.h"
#import "WebView+Karelia.h"
#import "NSView+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "NSURL+Karelia.h"

#import <QuartzCore/QuartzCore.h>


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
    [self setSelectedPageletHTMLElement:nil];
	[self setAnimationCoverWindow:nil];
    [self setAnimationTimer:nil];
    [self setTransitionFilter:nil];
    
	[self setMainWebViewComponent:nil];
	[myWebViewComponents release];
	[mySuspendedKeyPaths release];
	[mySuspendedKeyPathsAwaitingRefresh release];
	
	[myTextEditingBlock release];
	[myUndoManagerProxy release];
	[myInlineImageNodes release];
	[myInlineImageElements release];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[super dealloc];
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

- (WebView *)webView { return myWebView; }

- (void)setWebView:(WebView *)aWebView
{
	// Clear old delegates to avoid memory bugs
    WebView *oldWebView = [self webView];
    [oldWebView setEditingDelegate:nil];
    [oldWebView setFrameLoadDelegate:nil];
    [oldWebView setPolicyDelegate:nil];
    [oldWebView setResourceLoadDelegate:nil];
    [oldWebView setUIDelegate:nil];
    
	
    // Store new webview
	[aWebView retain];
	[myWebView release];
	myWebView = aWebView;
	
    
    // Setup new delegation
	[[self webView] setEditingDelegate:self];
}

- (NSTextView *)sourceCodeTextView { return oSourceTextView; }

- (KTDocWindowController *)windowController { return myWindowController; }

- (void)setWindowController:(KTDocWindowController *)aWindowController
{
	// In adition to standard accessor behaviour, keep an eye out for the document closing and for changes to the selected pages.
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"KTDocumentWillClose" object:[self document]];
	
	myWindowController = aWindowController;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentWillClose:) name:@"KTDocumentWillClose" object:[self document]];
}

- (KTDocument *)document { return [[self windowController] document]; }

- (BOOL)isWebViewLoading { return myWebViewIsLoading; }

- (void)setWebViewLoading:(BOOL)isLoading { myWebViewIsLoading = isLoading; }

- (NSString *)savedPageletStyle { return mySavedPageletStyle; }

- (void)setSavedPageletStyle:(NSString *)aSavedPageletStyle
{
	[aSavedPageletStyle retain];
	[mySavedPageletStyle release];
	mySavedPageletStyle = aSavedPageletStyle;
}

- (DOMHTMLElement *)selectedPageletHTMLElement
{
	return mySelectedPageletHTMLElement;
}

- (void)setSelectedPageletHTMLElement:(DOMHTMLElement *)aSelectedPageletHTMLElement
{
	[self setHilite:NO	 onHTMLElement:mySelectedPageletHTMLElement];
	[self setHilite:YES onHTMLElement:aSelectedPageletHTMLElement];
	
	[aSelectedPageletHTMLElement retain];
	[mySelectedPageletHTMLElement release];
	mySelectedPageletHTMLElement = aSelectedPageletHTMLElement;
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

- (WebScriptObject *)windowScriptObject { return myWindowScriptObject; }

- (void)setWindowScriptObject:(WebScriptObject *)aWindowScriptObject
{
    [aWindowScriptObject retain];
    [myWindowScriptObject release];
    myWindowScriptObject = aWindowScriptObject;
}

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
		[self setWebViewNeedsReload];
	}
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
#pragma mark Update / Animation

- (void)updateWebViewX
{
	/*
	
		id selectedItem = [selection objectAtIndex:0];
        
        if ( [selectedItem isDeleted] )
        {
            OFF((@"WebView told to load deleted page, substituting root. Page: %@", [selectedItem managedObjectDescription]));
            selectedItem = [[self document] root];
            [[[self windowController] siteOutline] selectItem:selectedItem];
            return;
        }
		
		NSScrollView *scrollView=firstScrollView([self webView]);
		if (scrollView && !([self windowController]->myHasSavedVisibleRect))
		{
			([self windowController]->myDocumentVisibleRect) = [scrollView documentVisibleRect];
			([self windowController]->myHasSavedVisibleRect)=YES;
		}
		
		[[WebPreferences standardPreferences] setJavaScriptEnabled:YES];	// enable javascript to force + button to work
		
		[[self webView] setPreferences:[WebPreferences standardPreferences]];	// force it to load new prefs
		(void) [selectedItem loadIntoWebView:[self webView]];
//		NSString *scrolledResult = [oWebView stringByEvaluatingJavaScriptFromString:
//			[NSString stringWithFormat:@"window.scrollTo(0,%@)", yPos]];
//		NSLog(@"result of scroll was %@", scrolledResult);
	}*/
}

- (void)updateWebViewAnimated
{
	// Clear things just in case
	[self setAnimationTimer:nil];
	[self setTransitionFilter:nil];
	if ([self animationCoverWindow])
	{
		[[[self windowController] window] removeChildWindow:[self animationCoverWindow]];
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
		subWindowRect.origin = [[[self windowController] window] convertBaseToScreen:subWindowRect.origin];
		
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
		[[[self windowController] window] addChildWindow:childWindow ordered:NSWindowAbove];
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

- (void)startAnimation:(id)bogus
{
	// For now, just remove the temporary child window.
	if (nil == [self animationTimer] || ![[self animationTimer] isValid])	// not already started?
	{
		// Get the "before" image
		NSImageView *imageView = [[self animationCoverWindow] contentView];
		CIImage *sourceImage = [[imageView image] toCIImage];
		// [[bitmap TIFFRepresentation] writeToFile:[@"~/Desktop/END.tiff" stringByExpandingTildeInPath] atomically:NO];
		
		// Capture the "after" image
		NSRect r = [[self webView] bounds];
		NSBitmapImageRep *bitmap = [[self webView] bitmapImageRepForCachingDisplayInRect:r];
		[[self webView] cacheDisplayInRect:r toBitmapImageRep:bitmap];
		// DON'T USE THIS "OLD" TECHNIQUE -- IT DOESN'T SEEM TO CAPTURE THE *NEW* IMAGE!
		//[oWebView lockFocus];
		//NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:r];
		//[oWebView unlockFocus];
		
		CIImage *destImage = [[[CIImage alloc] initWithBitmapImageRep:bitmap] autorelease];
		
		// Determine filter to use from defaults
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		// Set initial image inputs
		[[self transitionFilter] setDefaults];
		[[self transitionFilter] setValue:sourceImage forKey:@"inputImage"];
		[[self transitionFilter] setValue:destImage forKey:@"inputTargetImage"];
		
		// Get other inputs as specified from defaults; apply legal ones
		NSSet *legalInputKeys = [NSSet setWithArray:[[self transitionFilter] inputKeys]];
		NSDictionary *filterParams = [defaults objectForKey:@"CIFilterParameters"];
		NSEnumerator *theEnum = [filterParams keyEnumerator];
		id key;
		while (nil != (key = [theEnum nextObject]) )
		{
			if ([legalInputKeys containsObject:key])
			{
				[[self transitionFilter] setValue:[filterParams objectForKey:key] forKey:key];
			}
		}
		
		// Set other inputs that may be valid as well
		if ([legalInputKeys containsObject:@"inputExtent"])
		{
			CIVector	 *extent = [CIVector vectorWithX: 0	 Y: 0  Z: r.size.width	W:r.size.height ];
			[[self transitionFilter] setValue:extent forKey:@"inputExtent"];
		}
		if ([legalInputKeys containsObject:@"inputCenter"])
		{
			NSPoint relativeMouseLoc = [[self webView] convertPoint:myAnimateStartingPoint fromView:nil];
			
			[[self transitionFilter] setValue:[CIVector vectorWithX: relativeMouseLoc.x-r.origin.x Y: relativeMouseLoc.y-r.origin.y]
								  forKey:@"inputCenter"];
		}
		if ([legalInputKeys containsObject:@"inputShadingImage"])
		{
			static CIImage *sShadingCIImage = nil;
			if (nil == sShadingCIImage)
			{
				sShadingCIImage = [[CIImage imageWithData:
					[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:@"Shading"]]] retain];
			}
			[[self transitionFilter] setValue:sShadingCIImage forKey:@"inputShadingImage"];
		}
		if ([legalInputKeys containsObject:@"inputMaskImage"])
		{
			static CIImage *sDisintegrateCIImage = nil;
			if (nil == sDisintegrateCIImage)
			{
				// load image, but tile it so it will fit.
				CIImage *im
				= [CIImage imageWithData:
					[NSData dataWithContentsOfFile:
						[[NSBundle mainBundle] pathForImageResource:@"Mask"]]];
				
				CIFilter *f = [CIFilter filterWithName:@"CIAffineTile"];
				[f setValue:[NSAffineTransform transform] forKey:@"inputTransform"];
				[f setValue:im forKey:@"inputImage"];
				sDisintegrateCIImage = [[f valueForKey:@"outputImage"] retain];
			}
			[[self transitionFilter] setValue:sDisintegrateCIImage forKey:@"inputMaskImage"];
		}
		if ([legalInputKeys containsObject:@"inputBacksideImage"])	// for page flip
		{
			// Source image, but greatly reduced contrast, as flip image.
			CIFilter *f = [CIFilter filterWithName:@"CIColorControls"];
			[f setDefaults];
			[f setValue:[NSNumber numberWithFloat:0.333] forKey:@"inputContrast"];
			[f setValue:sourceImage forKey:@"inputImage"];
			CIImage *reducedContrastImage = [f valueForKey:@"outputImage"];
			[[self transitionFilter] setValue:reducedContrastImage forKey:@"inputBacksideImage"];
			// Additional Hack -- default value for page curl sucks, give it a better default
			if ([legalInputKeys containsObject:@"inputAngle"]
				&& nil == [filterParams objectForKey:@"inputAngle"])
			{
				[[self transitionFilter] setValue:[NSNumber numberWithFloat:0.7] forKey:@"inputAngle"];
			}
		}
		
		// Kick off the timer now, firing every thirtieth of a second
		NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval: 1.0/30.0  target: self
														selector: @selector(timerFired:)	userInfo: nil  repeats: YES];
		[self setAnimationTimer:timer];
		
		[self setBaseTime:[NSDate timeIntervalSinceReferenceDate]];
		
		[self setTotalAnimationTime:[defaults floatForKey:@"AnimationTime"]];
		if ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask)		// shift key -- slow down animation
		{
			[self setTotalAnimationTime:5.0];
		}
		
		[[NSRunLoop currentRunLoop] addTimer:timer  forMode: NSDefaultRunLoopMode];
	}
}

- (void)timerFired:(id)sender
{
	NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - [self baseTime];
	if (elapsed < [self totalAnimationTime])
	{
		float fract = (elapsed / [self totalAnimationTime]);
		float timeValue = fract; // EASE FUNCTION: (sin((fract * M_PI) - M_PI_2) + 1.0 ) / 2.0;
								 //NSLog(@"elapsed = %.2f fract = %.2f timeValue = %.2f", elapsed, fract, timeValue);
		
		[[self transitionFilter] setValue: [NSNumber numberWithFloat:timeValue]
							  forKey: @"inputTime"];
		
		CIImage *uncroppedOutputImage = [[self transitionFilter] valueForKey: @"outputImage"];
		
		// Now crop it, for page curl's benefit
		NSSize size = [[self webView] bounds].size;
		CIFilter *crop = [CIFilter filterWithName: @"CICrop"
									keysAndValues:
			@"inputImage", uncroppedOutputImage,
			@"inputRectangle",
			[CIVector vectorWithX: 0	 Y: 0  Z: size.width  W: size.height], nil];
		CIImage *croppedOutputImage = [crop valueForKey: @"outputImage"];
		NSImage *newImage = [croppedOutputImage toNSImage];
		
		// [[newImage TIFFRepresentation] writeToFile:[[NSString stringWithFormat:@"~/Desktop/transition/%.2f.tiff", timeValue] stringByExpandingTildeInPath] atomically:NO];
		
		NSImageView *imageView = [[self animationCoverWindow] contentView];
		[imageView setImage:newImage];
		[imageView display];
	}
	else
	{
		[self setTransitionFilter:nil];
		[sender invalidate];
		//		[sender release];
		[[[self windowController] window] removeChildWindow:[self animationCoverWindow]];
		[self setAnimationCoverWindow:nil];
	}
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
#pragma mark WebViewPolicyDelegate


- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request
		  frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	@try	// To stop WebKit swallowing any exceptions which occur in this method.
	{
		// get the url from the information dictionary:
		NSURL *url = [actionInformation objectForKey:@"WebActionOriginalURLKey"];
		NSString *scheme = [url scheme];
		
		if([scheme isEqualToString:kKTDocumentEditorURLScheme]) {
			// we clicked a link that has our application-specific scheme, do whatever we want:
			
			NSRunAlertPanel(@"internal link clicked", @"You clicked an internal link that I caught.\nThat link's path was %@.", nil,nil,nil, [url path]);
			//NSPoint mouseLoc = [oWindow mouseLocationOutsideOfEventStream];
			//NSLog(@"link clicked at point: %f, %f", mouseLoc.x, mouseLoc.y);
			
			// then stop further processing:
			[listener ignore];
		}
		else if ([scheme isEqualToString:kKTPagePathURLScheme])
		{
			
		}
		else if([scheme isEqualToString:@"http"])
		{
			// Load extedrnally unless we loaded page by clicking on a sidebar -- not a link.
			int navigationType = [[actionInformation objectForKey:WebActionNavigationTypeKey] intValue];
			switch (navigationType)
			{
				case WebNavigationTypeOther:
				case WebNavigationTypeFormSubmitted:
				case WebNavigationTypeBackForward:
				case WebNavigationTypeReload:
				case WebNavigationTypeFormResubmitted:
					[listener use];
					break;
					
				case WebNavigationTypeLinkClicked:
				default:
					// load with user's preferred browser:
					[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];
					// don't continue loading this url in our view:
					[listener ignore];
			}
		}
		else if ([scheme isEqualToString:@"applewebdata"] && ([[actionInformation objectForKey:WebActionNavigationTypeKey] intValue] != WebNavigationTypeOther) )
		{
			KTPage *thePage = [[[self windowController] document] pageForURLPath:[url path]];
			if (!thePage)
			{
				[KSSilencingConfirmSheet alertWithWindow:[[self windowController] window]
											silencingKey:@"shutUpFakeURL"
												   title:NSLocalizedString(@"Non-Page Link",@"title of alert")
												  format:NSLocalizedString
					(@"You clicked on a link that would open a page that Sandvox cannot directly display.\n\n\t%@\n\nWhen you publish your website, you will be able to view the page with your browser.", @""),
					[url path]];
				[listener ignore];
			}
			else
			{
				[[[self windowController] siteOutlineController] setSelectedObjects:[NSArray arrayWithObject:thePage]];
				[listener use];	// it's been loaded for us I think
			}
		}
		else if([scheme isEqualToString:@"file"] )
		{
			if ([[actionInformation objectForKey:WebActionNavigationTypeKey] intValue] == WebNavigationTypeOther)
			{
				[listener use];
			}
			else
			{
				[listener ignore];
			}
		}
		else {
			// do the default stuff for other schemes:
			[listener use];
		}
	}
	@catch (NSException *exception)
	{
		[NSApp reportException:exception];
	}
}

/*	Supplements the above method to hande "open in new window" URLs.
 */
- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
														 request:(NSURLRequest *)request
													newFrameName:(NSString *)frameName
												decisionListener:(id < WebPolicyDecisionListener >)listener
{
	// Open the URL in the user's web browser
	[listener ignore];
	
	NSURL *URL = [request URL];
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:URL];
}

#pragma mark -
#pragma mark WebFrameLoadDelegate Methods

- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)aWindowScriptObject
{
	[self setWindowScriptObject:aWindowScriptObject];	// keep this around so we can clear the value later
	
	//related to webkit  bugzilla 6152 ... ggaren may work on it
	
	// work-around for retain loop: we make a proxy that doesn't retain self
	// Only create the helper once, though.
	//COMMENTING OUT CHECK FOR NOW -- PROBLEM WITH CONVERSE, removeWebScriptKey:@"helper", WE GOT A CRASH AFTER APPLYING THIS CHANGE.
//	id currentHelper = [aWindowScriptObject valueForKey:@"helper"];
//	if (nil == currentHelper || ![currentHelper isKindOfClass:[KTHelper class]])
//	{
		KTHelper *helper = [[KTHelper alloc] initWithWindowController:[self windowController]];
		[aWindowScriptObject setValue:helper forKey:@"helper"];
		[helper release];
//	}
}

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

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
	// Only report feedback for the main frame.
	if (frame == [sender mainFrame])
	{
		[[self windowController] setWebViewTitle:title];
		//		[self updateWindow];
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
		//		if ([defaults boolForKey:@"ShowSourceDrawer"])
		{
			WebDataSource *dataSource = [frame dataSource];
			id <WebDocumentRepresentation>	representation = [dataSource representation];
			NSString *source = nil;
			if ([representation canProvideDocumentSource])
			{
				source = [representation documentSource];
			}
			if (nil == source)
			{
				source =  NSLocalizedString(@"No Source Available", @"Warning when we cannot load HTML source of a web page");
			}
		}
		
		[self processEditableElementsFromElement:[[frame DOMDocument] documentElement]];
		
		[self setHilite:YES onHTMLElement:[self selectedPageletHTMLElement]];
		// need to do this with inline images too probably
		
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
	
	if ([requestURL hasNetworkLocation] && ![[NSUserDefaults standardUserDefaults] boolForKey:@"LiveDataFeeds"] && ![[requestURL scheme] isEqualToString:@"svxmedia"])
	{
		LOG((@"webView:resource:willSendRequest:%@ ....Forcing to ONLY load from any cache", requestURL));
		
		NSMutableURLRequest *mutableRequest = [[request mutableCopy] autorelease];
		[mutableRequest setCachePolicy:NSURLRequestReturnCacheDataDontLoad];	// don't load, but return cached value
		return mutableRequest;
	}
	else if ( nil != requestURL )
	{
		NSString *relativePath = [requestURL relativePath];
		if ( [relativePath hasPrefix:[NSString stringWithFormat:@"/%@", [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]]] )
		{
			switch ([[self windowController] publishingMode])
			{
				case kGeneratingPreview:
				{

					 NSMutableString *substituted = [NSMutableString stringWithString:[requestURL absoluteString]];
					 [substituted replaceOccurrencesOfString:@"applewebdata://" 
												  withString:[NSString stringWithFormat:@"media:/%@/", [[[self document] documentInfo] siteID]]
													 options:NSLiteralSearch 
													   range:NSMakeRange(0,[substituted length])];
					 
					 // OLDER WEBKIT:
					 // right: converts a string like this: applewebdata://71C3B191-A2A9-4589-8BAE-8A1F8CD1DE02/_Media/placeholder_large.jpeg
					 // to this:               media:/11D16F2645B64AB190E6/71C3B191-A2A9-4589-8BAE-8A1F8CD1DE02/_Media/placeholder_large.jpeg
					 //
					 // NEWER WEBKIT (JAN 2007):
					 //                applewebdata://81CA4F1D-BDC9-40B6-A71C-D124FD4EEB13/_Media/placeholder_large.jpeg
					 //to media:/F46E731F6A6A442D8E67/242AABE8-4F4F-4F83-8121-09632B149AF7/_Media/placeholder_large.jpeg      
					 
//					NSString *requestURLString = [requestURL absoluteString];
//					NSRange whereMedia = [requestURLString rangeOfString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]];
//					NSString *substitutedBAD = [NSString stringWithFormat:@"media:/%@%@",
//						[[self document] documentID],
//						[requestURLString substringFromIndex:NSMaxRange(whereMedia)]];
					// WRONG - it forms url like this:  media:/11D16F2645B64AB190E6/placeholder_large.jpeg
					
					
					//NSLog(@"intercepted URL: %@", [requestURL absoluteString]);
					NSURL *substituteURL = [NSURL URLWithUnescapedString:substituted];
					//NSLog(@"substituting URL: %@", [substituteURL absoluteString]);
					return [NSURLRequest requestWithURL:substituteURL];
				}
				default:
					break;
			}
		}
		else if ( [[requestURL scheme] isEqualToString:@"svxmedia"] )
		{
			NSURLRequest *result = request; 
			
			// find our media container from the URL
			NSString *requestURLString = [requestURL absoluteString];
			NSString *mediaIdentifier = [requestURLString lastPathComponent];
			
			KTMediaContainer *mediaContainer = [[[self document] mediaManager] mediaContainerWithIdentifier:mediaIdentifier];
			KTMediaFile *mediaFile = [mediaContainer file];
			NSString *path = [mediaFile currentPath];
			if (path)
			{
				NSURL *substituteURL = [NSURL fileURLWithPath:path];
				result = [NSURLRequest requestWithURL:substituteURL];
			}
			else
			{
				LOG((@"error: could not find media container for %@", requestURL));
			}
			
			return result;
		}
		else
		{
			OFF((@"requestURL = %@", requestURL));
		}
		
		//	Handle pointers to the resources folder. e.g. "sandvox_Aqua/main.css"
		KTDesign *design = [[(KTPage *)[[self mainWebViewComponent] parsedComponent] master] design];
		if ([relativePath hasPrefix:[NSString stringWithFormat:@"/%@", [design remotePath]]])
		{
			NSURL *URL = [NSURL fileURLWithPath:[[design bundle] pathForResource:@"main" ofType:@"css"]];
			NSURLRequest *result = [NSURLRequest requestWithURL:URL cachePolicy:[request cachePolicy] timeoutInterval:[request timeoutInterval]];
			return result;
		}
	}
	
	// if not a Media URL and not kGeneratingPreview,
	// just return the original request
	return request;
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

- (void)selectPagelet:(KTPagelet *)aPagelet	// select on the new page
{
	NSString *divID = [NSString stringWithFormat:@"k-%@", [aPagelet uniqueID]];
	
	DOMDocument *document = [[[self webView] mainFrame] DOMDocument];
	DOMElement *element = [document getElementById:divID];

	[self setSelectedPageletHTMLElement:(DOMHTMLElement *)element];
	[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:aPagelet];
}

- (void)setHilite:(BOOL)inHilite onHTMLElement:(DOMHTMLElement *)aSelectedPageletHTMLElement
{
	if (aSelectedPageletHTMLElement)
	{
		if (inHilite)
		{
			NSString *hatchPath = [[NSBundle mainBundle] pathForImageResource:@"diamondplate"];
			NSURL *hatchURL = [NSURL fileURLWithPath:hatchPath];
			
			// store style
			[self setSavedPageletStyle:[aSelectedPageletHTMLElement getAttribute:@"style"]];
			[aSelectedPageletHTMLElement setAttribute:@"style"
													 :[NSString stringWithFormat:@"outline:auto 1px #d8b300; background:url(%@);", hatchURL]];	// yellow
		}
		else
		{
			// use saved style
			[aSelectedPageletHTMLElement setAttribute:@"style"
													 :[self savedPageletStyle]];
		}
	}		
}

@end
