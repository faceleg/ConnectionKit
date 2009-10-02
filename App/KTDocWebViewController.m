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
#import "KTMaster+Internal.h"
#import "KTPage.h"
#import "KTWebViewComponent.h"
#import "KTAppDelegate.h"
#import "KTDocument.h"
#import "KTSite.h"

#import "KTImageScalingURLProtocol.h"
#import "KTMediaManager+Internal.h"
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
    [self setSelectedPageletHTMLElement:nil];
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
#ifdef VARIANT_BETA
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
#pragma mark HTML Validation

- (IBAction)validateSource:(id)sender
{
	KTPage *page = [self page];
    NSString *pageSource = [page contentHTMLWithParserDelegate:nil isPreview:NO];
	
    NSString *charset = [[page master] valueForKey:@"charset"];
	NSStringEncoding encoding = [charset encodingFromCharset];
	NSData *pageData = [pageSource dataUsingEncoding:encoding allowLossyConversion:YES];
	
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sandvox_source.html"];
	NSString *pathOut = [NSTemporaryDirectory() stringByAppendingPathComponent:@"validation.html"];
	[pageData writeToFile:path atomically:NO];
	
	// curl -F uploaded_file=@karelia.html -F ss=1 -F outline=1 -F sp=1 -F noatt=1 -F verbose=1  http://validator.w3.org/check
	NSString *argString = [NSString stringWithFormat:@"-F uploaded_file=@%@ -F ss=1 -F verbose=1 http://validator.w3.org/check", path, pathOut];
	NSArray *args = [argString componentsSeparatedByString:@" "];
	
	NSTask *task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/usr/bin/curl"];
	[task setArguments:args];
	
	[[NSFileManager defaultManager] createFileAtPath:pathOut contents:[NSData data] attributes:nil];
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:pathOut];
	[task setStandardOutput:fileHandle];
	
#ifndef DEBUG
	// Non-debug builds should throw away stderr
	[task setStandardError:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
#endif
	[task launch];
	[task waitUntilExit];
	int status = [task terminationStatus];
	
	if (0 == status)
	{
		// Scrape page to get status
		BOOL isValid = NO;
		NSString *resultingPageString = [[[NSString alloc] initWithContentsOfFile:pathOut
																		 encoding:NSUTF8StringEncoding
																			error:nil] autorelease];
		if (nil != resultingPageString)
		{
			NSRange foundValidRange = [resultingPageString rangeBetweenString:@"<h2 class=\"valid\">" andString:@"</h2>"];
			if (NSNotFound != foundValidRange.location)
			{
				isValid = YES;
				NSString *explanation = [resultingPageString substringWithRange:foundValidRange];
				
				NSRunInformationalAlertPanelRelativeToWindow(
                                                             NSLocalizedString(@"HTML is Valid",@"Title of results alert"),
                                                             NSLocalizedString(@"The validator returned the following status message:\n\n%@",@""),
                                                             nil,nil,nil, [[self view] window], explanation);
			}
		}
		
		if (!isValid)		// not valid -- load the page, give them a way out!
		{
			[self setViewType:KTHTMLValidationView];
			[self setWebViewLoading:YES];	//  Otherwise, the WebViewPolicyDelegate will refuse the request.
			[[[self webView] mainFrame] loadData:[NSData dataWithContentsOfFile:pathOut]
                                                            MIMEType:@"text/html"
                                                    textEncodingName:@"utf-8" baseURL:[NSURL URLWithString:@"http://validator.w3.org/"]];
			[self performSelector:@selector(showValidationResultsAlert) withObject:nil afterDelay:0.0];
		}
	}
	else
	{
		[KSSilencingConfirmSheet
         alertWithWindow:[[self view] window]
         silencingKey:@"shutUpValidateError"
         title:NSLocalizedString(@"Unable to Validate",@"Title of alert")
         format:NSLocalizedString(@"Unable to post HTML to validator.w3.org:\n%@", @"error message"), path];
	}
}

- (void)showValidationResultsAlert
{
    [KSSilencingConfirmSheet
     alertWithWindow:[[self view] window]
     silencingKey:@"shutUpNotValidated"
     title:NSLocalizedString(@"Validation Results Loaded",@"Title of alert")
     format:NSLocalizedString(@"The results from the HTML validator have been loaded into Sandvox's web view. To return to the standard view of your web page, choose the 'Reload Web View' menu.", @"validated message")];
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
		[[[self webView] window] removeChildWindow:[self animationCoverWindow]];
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
	NSMutableURLRequest *result = [[request mutableCopy] autorelease];
	
    
	if ([requestURL isEqual:[request mainDocumentURL]])
    {
        // Force webkit to reload subresources all the time. BUGSID:35835
        [result setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    }
    else if ([requestURL hasNetworkLocation] &&
        ![[NSUserDefaults standardUserDefaults] boolForKey:@"LiveDataFeeds"] &&
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
                                                value:[NSString stringWithFormat:@"outline:auto 1px #d8b300; background:url(%@);", hatchURL]];	// yellow
		}
		else
		{
			// use saved style
			[aSelectedPageletHTMLElement setAttribute:@"style"
                                                value:[self savedPageletStyle]];
		}
	}		
}

@end
