//
//	KTDocWindowController+WebView.m
//	Marvel
//
//	Created by Dan Wood on 5/4/05.
//	Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTDocWindowController.h"

#import "KT.h"
#import "KTAppDelegate.h"
#import "KTInfoWindowController.h"
#import "KTDesign.h"
#import "KTDesignManager.h"
#import "KTDocument.h"
#import "KTKeyPathURLProtocol.h"
#import "KTMediaManager.h"
#import "KTTextField.h"
#import "Registration.h"
#import <KTComponents/KTComponents.h>
#import <KTComponents/PrivateComponents.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreServices/CoreServices.h>
#import "Registration.h"

NSString *KTSelectedDOMRangeKey = @"KTSelectedDOMRange";


@interface NSObject (WebBridgeHack )
- (DOMRange *)dragCaretDOMRange;
@end

@interface NSView ( WebBridgeHack )
- (id) _bridge;	// WebFrameBridge
@end

/*!	Class that forwards things to the target object, which is NOT retained.
*/

@interface KTHelper : NSObject
{
	id				myWindowController;
}

- (id)controller;

@end

@implementation KTHelper

- (id)initWithWindowController:(id)aWindowController
{
	if (self = [super init])
	{
		myWindowController = aWindowController;		// NOT RETAINED
	}
	return self;
}


- (id)controller
{
	return myWindowController;
}


/*!	Called from javascript "replaceElement" ... pressing of "+" button ... puts back an element that was empty
*/
- (void)replace:(DOMNode *)aNode withElementName:(NSString *)anElement elementClass:(NSString *)aClass elementID:(NSString *)anID text:(NSString *)aText innerSpan:(BOOL)aSpan innerParagraph:(BOOL)aParagraph
{
	DOMHTMLElement *newElement = [aNode replaceWithElementName:anElement elementClass:aClass elementID:anID text:aText innerSpan:aSpan innerParagraph:aParagraph];

	// Get it ready to edit (take off image substitution)
	DOMHTMLElement *selectedNode = [myWindowController selectableNodeEnclosing:newElement];
	if (nil != selectedNode)
	{
		(void) [myWindowController setEditingPropertiesFromSelectedNode:selectedNode];
		[selectedNode focus];
		
	}
}


/*!	Called from javascript "replaceText" -- replace the node with just some text.
*/
- (void)replace:(DOMNode *)aNode withText:(NSString *)aText
{
	[aNode replaceWithText:aText];
}




+ (BOOL)isSelectorExcludedFromWebScript:(SEL)sel
{
	return (sel != @selector(replace:withElementName:elementClass:elementID:text:innerSpan:innerParagraph:)
			&&  sel != @selector(replace:withText:));
}
+ (NSString *) webScriptNameForSelector:(SEL)sel
{
	if (sel == @selector(replace:withElementName:elementClass:elementID:text:innerSpan:innerParagraph:))
	{
		return @"replaceElement";
	}
	if (sel == @selector(replace:withText:))
	{
		return @"replaceText";
	}
	return @""; // [NSStringFromSelector(sel) stringByReplacing:@":" with:@"_"];
}


#if 0
/*!	Ask the target for its method signature
*/
-(NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature *result = [super methodSignatureForSelector:aSelector];
	if (nil == result)
	{
		result = [myTarget methodSignatureForSelector:aSelector];
	}
	return result;
}

-(void)forwardInvocation:(NSInvocation *)anInvocation
{
	if (nil != anInvocation)
	{
		[anInvocation invokeWithTarget:myTarget];
	}
}
#endif

@end



@interface KTDocWindowController ( WebViewPrivate )

- (DOMHTMLElement *)pageletElementEnclosing:(DOMNode *)aNode;
- (DOMHTMLElement *)selectedPageletHTMLElement;
- (void)setSelectedPageletHTMLElement:(DOMHTMLElement *)aSelectedPageletHTMLElement;
- (NSString *)savedPageletStyle;
- (void)setSavedPageletStyle:(NSString *)aSavedPageletStyle;
- (NSPoint)linkPanelTopLeftPointForSelectionRect:(NSRect)aSelectionRect;


- (KTPage *)pageFromURLPath:(NSString *)aPath;
- (KTPagelet *)pageletEnclosing:(DOMNode *)aDomNode;
- (void)updateCreateLinkMenuItem;

- (void)processMedia;

- (void)selectInlineIMGNode:(DOMNode *)aNode container:(KTAbstractPlugin *)aContainer;

- (NSString *)createLink:(NSString *)link withContextInformation:(NSDictionary *)info;
- (NSString *)editLink:(NSString *)newLink withContextInformation:(NSDictionary *)info;
- (NSString *)removeLinkWithContextInformation:(NSDictionary *)info;

- (void)insertHref:(NSString *)aURLAsString inRange:(DOMRange *)aRange;
- (void)insertText:(NSString *)aTextString href:(NSString *)aURLAsString inRange:(DOMRange *)aRange atPosition:(long)aPosition;

@end


NSScrollView * firstScrollView(NSView *aView)
{
	NSArray *aSubviewsArray=[aView subviews];
	unsigned i;
	for (i=0;i<[aSubviewsArray count];i++) {
		if ([[aSubviewsArray objectAtIndex:i] isKindOfClass:[NSScrollView class]]) {
			return [aSubviewsArray objectAtIndex:i];
		}
	}
	for (i=0;i<[aSubviewsArray count];i++) {
		NSScrollView *scrollview=firstScrollView([aSubviewsArray objectAtIndex:i]);
		if (scrollview) return scrollview;
	}
	return nil;
}


@implementation KTDocWindowController ( WebView )


- (NSString *)savedPageletStyle
{
	return mySavedPageletStyle;
}

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

- (void) setHilite:(BOOL)inHilite onHTMLElement:(DOMHTMLElement *)aSelectedPageletHTMLElement
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
													 :mySavedPageletStyle];
		}
	}		
}

- (void)setSelectedPageletHTMLElement:(DOMHTMLElement *)aSelectedPageletHTMLElement
{
	[self setHilite:NO	 onHTMLElement:mySelectedPageletHTMLElement];
	[self setHilite:YES onHTMLElement:aSelectedPageletHTMLElement];
	
	[aSelectedPageletHTMLElement retain];
	[mySelectedPageletHTMLElement release];
	mySelectedPageletHTMLElement = aSelectedPageletHTMLElement;
}

- (void) webViewDeallocSupport
{
	// No longer using, no longer doing author/address from prefs
	//	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	//	
	//	[controller removeObserver:self forKeyPath:@"values.author"];
	//	[controller removeObserver:self forKeyPath:@"values.KTAddress"];

	[oWebView stopLoading:nil];

	[self setSelectedPageletHTMLElement:nil];
	[self setSelectedPagelet:nil];
	
    [oWebView setFrameLoadDelegate:nil];
    [oWebView setPolicyDelegate:nil];
    [oWebView setResourceLoadDelegate:nil];
    [oWebView setUIDelegate:nil];
	[oWebView setEditingDelegate:nil];
}

/*!	More initialization code specific to the webview, called from windowDidLoad
*/

- (void)webViewDidLoad
{
	// Register for requests to refresh the webview
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(webviewMayNeedRefreshing:)
												 name:kKTWebViewMayNeedRefreshingNotification
											   object:nil];
	
	// Register for requests to change the current page's design
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(designChangedNeedWebViewUpdate:)
												 name:kKTDesignChangedNotification
											   object:[self document]];
	
	// No longer using, no longer doing author/address from prefs
	//	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	//	
	//	[controller addObserver:self forKeyPath:@"values.author" options:(NSKeyValueObservingOptionNew) context:nil];
	//	[controller addObserver:self forKeyPath:@"values.KTAddress" options:(NSKeyValueObservingOptionNew) context:nil];
	
	[self setImageReplacementRegistry:[NSMutableDictionary dictionary]];
	[self setReplacementImages:[NSMutableDictionary dictionary]];
	
	[oWebView setEditingDelegate:self];			// WebEditingDelegate
	[oWebView setPolicyDelegate:self];			// WebPolicyDelegate
	[oWebView setFrameLoadDelegate:self];		// WebFrameLoadDelegate
	[oWebView setResourceLoadDelegate:self];	// WebResourceLoadDelegate
	[oWebView setApplicationNameForUserAgent:@"Sandvox"];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[oWebView setContinuousSpellCheckingEnabled:[defaults boolForKey:@"ContinuousSpellChecking"]];
	// Set UI delegate -- we don't actually use the built-in methods, but we use our custom
	// method for detecting clicks.
	[oWebView setUIDelegate:self];				// WebUIDelegate
	
	[oWebView setTextSizeMultiplier:[[[self document] valueForKey:@"textSizeMultiplier"] floatValue]];
	
	/*
	 // doesn't actually work yet
	 DOMDocument *document = [[oWebView mainFrame] DOMDocument];
	 [document addEventListener:@"mousedown"
							   :self
							   :YES];
	 */
	[self setStatusField:@""];
}

#pragma mark -
#pragma mark Update / Animation

- (void)updateWebView:(id)sender
{
	if ([self webViewIsEditing])
	{
		// Act as if we ended editing, so changes get saved
		(void) [self webView:oWebView shouldEndEditingInDOMRange:nil];	// manually call this to force some stuff that's skipped if we end this way
		
		// DON'T suspend
		[self setSuspendNextWebViewUpdate:DONT_SUSPEND];
	}		
	[[self document] setViewType:kKTNormalView];
	[self updateWebView];	// yes, go ahead and do it now explicitly
}

/*! updates the webview to "preview" the currently selected item

GENERALLY, DO NOT CALL THIS DIRECTLY ... let it be called only once.
Otherwise, try webviewMayNeedRefreshing: with nil parameter, or post
kKTWebViewMayNeedRefreshingNotification
*/

- (void)updateWebView
{
	//LOG((@"updating webView via debug menu"));
	
	[[[self document] managedObjectContext] processPendingChanges];
	
	[[NSApp delegate] updateDuplicateMenuItemForDocument:[self document]];
	[[NSApp delegate] updateWebViewMenuItemsForDocument:[self document]];

	NSArray *selection = [oSiteOutline selectedItems];
	if ( (nil == selection) || ([selection count] == 0) )
	{
		[[oWebView mainFrame] loadHTMLString:@"" baseURL:nil];
	}
	else if ( [selection count] == 1 )
	{
		id selectedItem = [selection objectAtIndex:0];
        
        if ( [selectedItem isDeleted] )
        {
            LOG((@"WebView told to load deleted page, substituting root. Page: %@", [selectedItem managedObjectDescription]));
            selectedItem = [[self document] root];
            [oSiteOutline selectItem:selectedItem];
            return;
        }
                
		if ( ![selectedItem isDeleted] )
		{
			NSScrollView *scrollView=firstScrollView(oWebView);
			// NSLog(@"found scrollview: %@",[scrollView description]);
			if (scrollView && !myHasSavedVisibleRect)
			{
				myDocumentVisibleRect=[scrollView documentVisibleRect];
				myHasSavedVisibleRect=YES;
			}
			(void) [selectedItem loadIntoWebView:oWebView];
			//			NSString *scrolledResult = [oWebView stringByEvaluatingJavaScriptFromString:
			//				[NSString stringWithFormat:@"window.scrollTo(0,%@)", yPos]];
			//			NSLog(@"result of scroll was %@", scrolledResult);
		}
		else
		{
			[[oWebView mainFrame] loadHTMLString:@"<html><head></head><body>WebView is trying to load a deleted page!<br/>This indicates that selection in the outline is wrong (likely after an Undo).</body></html>" baseURL:nil];
		}
	}
	else
	{
		// put up the multiple selection page
		NSString *pagePath = [[NSBundle mainBundle] pathForResource:@"MultipleSelection" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:pagePath];
		NSMutableString *text = [[[NSMutableString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		if (nil == text) text=[NSMutableString string];
		NSString *iconURLPath = [[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForImageResource:@"multiselection"]] absoluteString];
		[text replace:@"_ICONPATH_" with:iconURLPath];
			

		[[oWebView mainFrame] loadHTMLString:text baseURL:nil];
	}
	[self setStatusField:@""];		// clear out status field, need to move over something to get it populated
}

- (void)updateWebViewAnimated
{
	// Clear things just in case
	[self setAnimationTimer:nil];
	[self setTransitionFilter:nil];
	if (nil != myAnimationCoverWindow)
	{
		[[self window] removeChildWindow:myAnimationCoverWindow];
		[self setAnimationCoverWindow:nil];
	}
	// (stop loading just in case it was already loading, to handle multiple clicks.
	[[oWebView mainFrame] stopLoading];

	// First figure out if we can animate
	CIFilter *filter = nil;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *filterName = [defaults objectForKey:@"CIFilterNameForAnimation"];		
	
	if (nil != filterName)
	{
		filter = [CIFilter filterWithName: filterName];
	}
	
	
	// ANIMATION ONLY WORKS IF WE HAVE FAST CORE IMAGE ... OTHERWISE THERE'S NO POINT!
	
	if ([defaults boolForKey:@"DoAnimations"] && [KTAppDelegate fastEnoughProcessor] && [KTAppDelegate coreImageAccelerated]
		&& nil != filter
		&& ([[defaults objectForKey:@"AnimationTime"] floatValue] > 0.0))
	{
		[self setTransitionFilter:filter];
		
		NSView *theView = oWebView;
		
		NSRect r= [theView bounds];
		// DON'T USE THE TIGER-API TECHNIQUE -- IT DOESN'T CAPTURE ANTI-ALIASED TEXT QUITE RIGHT.
		// NSBitmapImageRep *bitmap = [oWebView bitmapImageRepForCachingDisplayInRect:r];
		// OLD TECHNIQUE [oWebView cacheDisplayInRect:r toBitmapImageRep:bitmap];
		[theView lockFocus];
		NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:r];
		[theView unlockFocus];
		
		NSRect subWindowRect = [theView convertRect:r toView:nil];
		subWindowRect.origin = [[self window] convertBaseToScreen:subWindowRect.origin];
		
		NSWindow *childWindow = [[[NSWindow alloc] initWithContentRect:subWindowRect
															 styleMask:NSBorderlessWindowMask
															   backing:NSBackingStoreBuffered
																 defer:YES] autorelease];
		NSImageView *imageView = [[[NSImageView alloc] initWithFrame:r] autorelease];
		NSImage *image = [NSImage imageWithBitmap:bitmap];
		
#warning BUG I reported to Apple: background images are slightly screwy in the snapshot.
		//	[[image TIFFRepresentation] writeToFile:[@"~/Desktop/START.tiff" stringByExpandingTildeInPath] atomically:NO];
		
		[imageView setImage:image];
		[childWindow setContentView:imageView];
		[[self window] addChildWindow:childWindow ordered:NSWindowAbove];
		[self setAnimationCoverWindow:childWindow];
		
		// Kick off animation after a short delay to get at least partial webview loaded.
		// If the webview finishes loading before that, it will cancel this.
		// First make sure it's not already queued up (in case of multiple clicks)
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startAnimation:) object:nil];
		[self performSelector:@selector(startAnimation:) withObject:nil afterDelay:0.01];
	}
	else
	{
		[self updateWebView];
	}
	
	// make sure we're seeing webview and styles
	[self normalView];
	
	
	// Animation won't really start until all the internal stuff is done anyhow, so it's just
	// a matter of painting to screen.	 So we started animation delayed almost immediately.
}

- (void)startAnimation:(id)bogus
{
	// For now, just remove the temporary child window.
	if (nil == myAnimationTimer || ![myAnimationTimer isValid])	// not already started?
	{
		// Get the "before" image
		NSImageView *imageView = [myAnimationCoverWindow contentView];
		CIImage *sourceImage = [[imageView image] toCIImage];
		// [[bitmap TIFFRepresentation] writeToFile:[@"~/Desktop/END.tiff" stringByExpandingTildeInPath] atomically:NO];
		
		// Capture the "after" image
		NSRect r = [oWebView bounds];
		NSBitmapImageRep *bitmap = [oWebView bitmapImageRepForCachingDisplayInRect:r];
		[oWebView cacheDisplayInRect:r toBitmapImageRep:bitmap];
		// DON'T USE THIS "OLD" TECHNIQUE -- IT DOESN'T SEEM TO CAPTURE THE *NEW* IMAGE!
		//[oWebView lockFocus];
		//NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:r];
		//[oWebView unlockFocus];
		
		CIImage *destImage = [[[CIImage alloc] initWithBitmapImageRep:bitmap] autorelease];
		
		// Determine filter to use from defaults
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		// Set initial image inputs
		[myTransitionFilter setDefaults];
		[myTransitionFilter setValue:sourceImage forKey:@"inputImage"];
		[myTransitionFilter setValue:destImage forKey:@"inputTargetImage"];
		
		// Get other inputs as specified from defaults; apply legal ones
		NSSet *legalInputKeys = [NSSet setWithArray:[myTransitionFilter inputKeys]];
		NSDictionary *filterParams = [defaults objectForKey:@"CIFilterParameters"];
		NSEnumerator *theEnum = [filterParams keyEnumerator];
		id key;
		while (nil != (key = [theEnum nextObject]) )
		{
			if ([legalInputKeys containsObject:key])
			{
				[myTransitionFilter setValue:[filterParams objectForKey:key] forKey:key];
			}
		}
		
		// Set other inputs that may be valid as well
		if ([legalInputKeys containsObject:@"inputExtent"])
		{
			CIVector	 *extent = [CIVector vectorWithX: 0	 Y: 0  Z: r.size.width	W:r.size.height ];
			[myTransitionFilter setValue:extent forKey:@"inputExtent"];
		}
		if ([legalInputKeys containsObject:@"inputCenter"])
		{
			NSPoint relativeMouseLoc = [oWebView convertPoint:myAnimateStartingPoint fromView:nil];
			
			[myTransitionFilter setValue:[CIVector vectorWithX: relativeMouseLoc.x-r.origin.x Y: relativeMouseLoc.y-r.origin.y]
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
			[myTransitionFilter setValue:sShadingCIImage forKey:@"inputShadingImage"];
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
			[myTransitionFilter setValue:sDisintegrateCIImage forKey:@"inputMaskImage"];
		}
		if ([legalInputKeys containsObject:@"inputBacksideImage"])	// for page flip
		{
			// Source image, but greatly reduced contrast, as flip image.
			CIFilter *f = [CIFilter filterWithName:@"CIColorControls"];
			[f setDefaults];
			[f setValue:[NSNumber numberWithFloat:0.333] forKey:@"inputContrast"];
			[f setValue:sourceImage forKey:@"inputImage"];
			CIImage *reducedContrastImage = [f valueForKey:@"outputImage"];
			[myTransitionFilter setValue:reducedContrastImage forKey:@"inputBacksideImage"];
			// Additional Hack -- default value for page curl sucks, give it a better default
			if ([legalInputKeys containsObject:@"inputAngle"]
				&& nil == [filterParams objectForKey:@"inputAngle"])
			{
				[myTransitionFilter setValue:[NSNumber numberWithFloat:0.7] forKey:@"inputAngle"];
			}
		}
		
		// Kick off the timer now, firing every thirtieth of a second
		NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval: 1.0/30.0  target: self
														selector: @selector(timerFired:)	userInfo: nil  repeats: YES];
		[self setAnimationTimer:timer];
		
		myBaseTime = [NSDate timeIntervalSinceReferenceDate];
		
		myTotalAnimationTime = [defaults floatForKey:@"AnimationTime"];
		if ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask)		// shift key -- slow down animation
		{
			myTotalAnimationTime *= 5.0;
		}
		
		[[NSRunLoop currentRunLoop] addTimer:timer  forMode: NSDefaultRunLoopMode];
	}
}

- (void)timerFired:(id)sender
{
	NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - myBaseTime;
	if (elapsed < myTotalAnimationTime)
	{
		float fract = elapsed / myTotalAnimationTime;
		float timeValue = fract; // EASE FUNCTION: (sin((fract * M_PI) - M_PI_2) + 1.0 ) / 2.0;
								 //NSLog(@"elapsed = %.2f fract = %.2f timeValue = %.2f", elapsed, fract, timeValue);
		
		[myTransitionFilter setValue: [NSNumber numberWithFloat:timeValue]
							  forKey: @"inputTime"];
		
		CIImage *uncroppedOutputImage = [myTransitionFilter valueForKey: @"outputImage"];
		
		// Now crop it, for page curl's benefit
		NSSize size = [oWebView bounds].size;
		CIFilter *crop = [CIFilter filterWithName: @"CICrop"
									keysAndValues:
			@"inputImage", uncroppedOutputImage,
			@"inputRectangle",
			[CIVector vectorWithX: 0	 Y: 0  Z: size.width  W: size.height], nil];
		CIImage *croppedOutputImage = [crop valueForKey: @"outputImage"];
		NSImage *newImage = [croppedOutputImage toNSImage];
		
		// [[newImage TIFFRepresentation] writeToFile:[[NSString stringWithFormat:@"~/Desktop/transition/%.2f.tiff", timeValue] stringByExpandingTildeInPath] atomically:NO];
		
		NSImageView *imageView = [myAnimationCoverWindow contentView];
		[imageView setImage:newImage];
		[imageView display];
	}
	else
	{
		[self setTransitionFilter:nil];
		[sender invalidate];
		//		[sender release];
		[[self window] removeChildWindow:myAnimationCoverWindow];
		[self setAnimationCoverWindow:nil];
	}
}

#pragma mark -
#pragma mark Image Replacement

- (NSString *)cssForImageReplacementEntry:(NSDictionary *)anEntry
{
	NSImage *image = [anEntry objectForKey:@"image"];
	NSString *designBundleIdentifier = [anEntry objectForKey:@"designBundleIdentifier"];
	NSSize size = [image size];
	//	NSString *code = [anEntry objectForKey:@"code"];
	NSString *uniqueID = [anEntry objectForKey:@"uniqueID"];
	NSString *imageName = [NSString stringWithFormat:@"replacementImages.%@.png",
		[anEntry objectForKey:@"imageKey"]];
	
	NSString *irPath = [[self document] pathForReplacementImageName:imageName designBundleIdentifier:designBundleIdentifier];
	
	static NSString *sImageReplacementEntry = nil;
	if (nil == sImageReplacementEntry)
	{
		NSString *path = [[NSBundle mainBundle] pathForResource:@"imageReplacementEntry" ofType:@"txt"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sImageReplacementEntry = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	}
	NSMutableString *result = [NSMutableString stringWithString:sImageReplacementEntry];
	[result replace:@"_UNIQUEID_" with:uniqueID];
	[result replace:@"_WIDTH_" with:[NSString stringWithFormat:@"%.0f", size.width]];
	[result replace:@"_HEIGHT_" with:[NSString stringWithFormat:@"%.0f", size.height]];
	[result replace:@"_URL_" with:irPath];
	return result;
}


/*! Generates CSS
*/

- (NSData *)generatedCSSForDesignBundleIdentifier:(NSString *)aDesignBundleIdentifier
{
	//LOG((@"IR>>>> %@", NSStringFromSelector(_cmd)));
	
	KTDesignManager *designManager = [[NSApp delegate] designManager];
	KTDesign *design = [designManager designForIdentifier:aDesignBundleIdentifier];
	
	NSData *result = nil;
	NSString *path = [[design bundle] pathForResource:@"main" ofType:@"css"];
	if (nil == path)
	{
		NSLog(@"Couldn't find main.css in bundle %@", aDesignBundleIdentifier);
		result = [NSData data];
	}
	else
	{
		NSError *error;
		NSMutableData *fileData = [NSMutableData dataWithContentsOfFile:path options:0 error:&error];
		
		// Now, possibly, append image replacement styles
		NSMutableDictionary *designEntry = [myImageReplacementRegistry objectForKey:aDesignBundleIdentifier];
		
		if (nil != designEntry && 0 != [designEntry count])
		{
			static NSString *sImageReplacementHeader = nil;
			if (nil == sImageReplacementHeader)
			{
				NSString *irPath = [[NSBundle mainBundle] pathForResource:@"imageReplacementHeader" ofType:@"txt"];
				NSData *data = [NSData dataWithContentsOfFile:irPath];
				sImageReplacementHeader = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
			}
			
			NSMutableString *buf = [NSMutableString stringWithString:sImageReplacementHeader];
			
			NSEnumerator *enumerator = [designEntry objectEnumerator];
			id item;
			
			while ( item = [enumerator nextObject] )
			{
				[buf appendString:[self cssForImageReplacementEntry:item]];
			}
			[buf appendString:@"\n"];
			
			//LOG((@"Additional CSS:\n%@", buf));
			
			NSData *additionalData = [buf dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
			[fileData appendData:additionalData];
		}
		
		// Now add Plugin-specific CSS
		NSMutableSet *additionalCSSFiles = [NSMutableSet set];
		KTPage *root = (KTPage *)[[self document] root];
		[root recursivePerformSelectorOnPageAndChildren:@selector(addCSSFilePathToSet:forPage:) withObject:additionalCSSFiles];
		NSEnumerator *theEnum = [additionalCSSFiles objectEnumerator];
		NSString *path;
		
		while (nil != (path = [theEnum nextObject]) )
		{
			NSData *additionalCSSData = [NSData dataWithContentsOfFile:path];
			[fileData appendData:additionalCSSData];
		}
		
		if (kGeneratingPreview == [[self document] publishingMode])
		{
			static NSData *sAdditionalCSSData = nil;
			if (nil == sAdditionalCSSData)
			{
				NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"additionalEditingCSS" ofType:@"txt"];
				sAdditionalCSSData = [[NSData alloc] initWithContentsOfFile:cssPath];
			}
			[fileData appendData:sAdditionalCSSData];
		}
		
		result = [NSData dataWithData:fileData];	// make it immutable
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults boolForKey:@"DebugImageReplacement"])
		{
			// NOW ... write this out so we can see the images
			NSString *path = [NSString stringWithFormat:@"%@/%@.css",
				NSTemporaryDirectory(),
				aDesignBundleIdentifier ];
			[result writeToFile:path atomically:NO];
			//LOG((@"IR>>>> wrote CSS to %@", path));
		}
	}
	return result;
}

- (NSString *)codeForDOMNodeID:(NSString *)anID		// id like k-Entity-Property-434-h1h
{
	NSArray *dashComponents = [anID componentsSeparatedByString:@"-"];
	if ([dashComponents count] < 5)
	{
		return nil;		// code is optional, so return nil if it's not there
	}
	NSString *property = [dashComponents objectAtIndex:4];
	return property;
}

- (NSString *)propertyNameForDOMNodeID:(NSString *)anID	// id like k-Entity-Property-434-h1h
{
	NSString *result = nil;
	NSArray *dashComponents = [anID componentsSeparatedByString:@"-"];
	if ([dashComponents count] > 2)
	{
		result = [dashComponents objectAtIndex:2];
	}
	return result;
}


- (id)itemForDOMNodeID:(NSString *)anID	// id like k-Entity-Property-434-h1h
{
	id result = nil;
	
	NSArray *dashComponents = [anID componentsSeparatedByString:@"-"];
	if ([dashComponents count] < 4)
	{
		return nil;
	}
	
	//	NSString *q			= [dashComponents objectAtIndex:0];
	NSString *entityName= [dashComponents objectAtIndex:1];
	//	NSString *property	= [dashComponents objectAtIndex:2];
	NSString *uniqueID	= [dashComponents objectAtIndex:3];
	//	NSString *code	= [dashComponents objectAtIndex:4];
	
	if ([entityName isEqualToString:@"Document"])
	{
		return [self document];		// don't need to look up object; it's this document!
	}
	else if ([entityName isEqualToString:@"Root"])
	{
		return [[self document] root];	// don't need to look up object; it's the root
	}
	
	// Strip off any "_" suffix to get the real entity name.  We allow _ suffix to make things unique
	int indexOfDash = [entityName rangeOfString:@"_"].location;
	if (NSNotFound != indexOfDash)
	{
		entityName = [entityName substringToIndex:indexOfDash];
	}
	
	// peform fetch
	NSManagedObjectContext *context = [[self document] managedObjectContext];
	NSError *fetchError = nil;
	NSArray *fetchedObjects = [context objectsWithEntityName:entityName
												   predicate:[NSPredicate predicateWithFormat:@"uniqueID like %@", uniqueID]
													   error:&fetchError];	
	// extract result
	if ( (nil != fetchedObjects) && ([fetchedObjects count] == 1) )
	{
		result = [fetchedObjects objectAtIndex:0];
	}
	
	return result;
}


/*!	Verifies that this is an editable entity.  Assumes it's an editable class; it makes sure if it's a page it's an editable summary
*/
- (BOOL)isEditableElement:(DOMHTMLElement *)aDOMHTMLElement
{
	NSString *theClass = [aDOMHTMLElement className];
	
	BOOL result = [DOMNode isEditableFromDOMNodeClass:theClass];
	if (result && [DOMNode isSummaryFromDOMNodeClass:theClass])
	{
		// further scrutiny if it's a summary element
		NSString *theID = [aDOMHTMLElement idName];
		if (nil != theID)
		{
			id selectedItem = [self itemForDOMNodeID:theID];
			if ([selectedItem isKindOfClass:[KTPage class]])
			{
				KTPage *page = (KTPage *)selectedItem;
				if ([page isCollection])
				{
					// yes only if the page is a KTSummarizeAutomatic summary type
					result = (KTSummarizeAutomatic == [[page valueForKey:@"collectionSummaryTypeInherited"] intValue]);
				}
			}
		}
	}
	return result;
}


/*!	Looks up from cache, generates if needed
*/
- (BOOL)useImageReplacementEntryForDesign:(NSString *)aDesign
								 uniqueID:(NSString *)aUniqueID
								   string:(NSString *)aString;
{
	BOOL result = NO;
	//LOG((@"IR>>>> %@ %@ %@ %@", NSStringFromSelector(_cmd), aDesign, aUniqueID, aString));
	
	NSMutableDictionary *designEntry = [myImageReplacementRegistry objectForKey:aDesign];
	if (nil == designEntry)
	{
		designEntry = [NSMutableDictionary dictionary];
		[myImageReplacementRegistry setObject:designEntry forKey:aDesign];		// put it in
																				//LOG((@"IR>>>> Created new entry in myImageReplacementRegistry for design:%@", aDesign));
	}
	
	NSString *replacementCode = [self codeForDOMNodeID:aUniqueID];
	NSMutableDictionary *renderEntry = [designEntry objectForKey:aUniqueID];
	
	KTDesign *design = [[[NSApp delegate] designManager] designForIdentifier:aDesign];
	
	NSNumber *aSize = nil;
	KTPage *selectedPage = [self selectedPage];
	id textMultiplier = [selectedPage valueForKey:@"addString1"];
	if (nil == textMultiplier)
	{
		aSize = [NSNumber numberWithFloat:1.0];
	}
	else
	{
		float size = [textMultiplier floatValue];
		size = round(size * 10.0) / 10.0;	// round to a multiple of 0.1
		aSize = [NSNumber numberWithFloat:size];
	}
//	LOG((@"size = %@", aSize));
	
	NSImage *renderedText = [design replacementImageForCode:replacementCode string:aString size:aSize];
	if (nil != renderedText)
	{
		if (nil == renderEntry)
		{
			static unsigned long sImageKeyNumber = 0;
			NSString *imageKey = [NSString stringWithFormat:@"k%ld", sImageKeyNumber++];

			
			// Somehow we're getting a bad entry for somebody, so log helpful info and bail if something is nil
			if (nil == imageKey || nil == replacementCode || nil == aUniqueID || nil == aString || nil == aDesign)
			{
				NSLog(@"%@ null item: %@ %@ %@ %@", NSStringFromSelector(_cmd), imageKey, replacementCode, 
					  aUniqueID, aString, aDesign);
				return NO;
			}
					
			renderEntry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				aDesign, @"designBundleIdentifier",
				aString, @"string",
				aSize, @"size",
				aUniqueID, @"uniqueID",
				replacementCode, @"code",
				imageKey, @"imageKey",
				renderedText, @"image",
				nil];
			[designEntry setObject:renderEntry forKey:aUniqueID];
			[myReplacementImages setObject:renderedText forKey:imageKey];
			//LOG((@"IR>>>> Created new render entry: %@ - %@ - %@", [renderEntry objectForKey:@"code"], [renderEntry objectForKey:@"imageKey"], [renderEntry objectForKey:@"uniqueID"]));
		}
		else if (![[renderEntry objectForKey:@"string"] isEqualToString:aString]	// different string
				 || fabsf([[renderEntry objectForKey:@"size"] floatValue] - [aSize floatValue]) > 0.01)	// or different size?
		{
			//LOG((@"IR>>>> Updated render Entry, string changed from %@ to %@", [renderEntry objectForKey:@"string"], aString));
			[renderEntry setObject:aString forKey:@"string"];
			[renderEntry setObject:aSize forKey:@"size"];
			[renderEntry setObject:renderedText forKey:@"image"];
			[myReplacementImages setObject:renderedText forKey:[renderEntry objectForKey:@"imageKey"]];
		}
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults boolForKey:@"DebugImageReplacement"])
		{
			// NOW ... write this out so we can see the images
			NSString *path = [NSString stringWithFormat:@"%@/IMG_%@_%@.png",
				NSTemporaryDirectory(),
				aUniqueID,
				[renderEntry objectForKey:@"imageKey"]];
			[[renderedText PNGRepresentation] writeToFile:path atomically:NO];
			LOG((@"IR>>>> wrote to %@", path));
		}
		result = YES;
	}
	return result;
}

/*!	Remove any image replacement being used.  For turning it off.
*/

- (void)removeImageReplacementEntryForDesign:(NSString *)aDesign
									uniqueID:(NSString *)aUniqueID
									  string:(NSString *)aString;
{
	NSMutableDictionary *designEntry = [myImageReplacementRegistry objectForKey:aDesign];
	if (nil == designEntry)
	{
		return;	// not there, so we don't need to remove anything
	}
	
	[designEntry removeObjectForKey:aUniqueID];
}

#pragma mark -
#pragma mark Accessors (Special)

- (int)suspendNextWebViewUpdate
{
	return mySuspendNextWebViewUpdate;
}

- (void)setSuspendNextWebViewUpdate:(int)aFlagCount
{
	mySuspendNextWebViewUpdate = aFlagCount;
}

- (void)setSelectedDomNode:(DOMNode *)aSelectedDomNode
{
	[aSelectedDomNode retain];
	[mySelectedDomNode release];
	mySelectedDomNode = aSelectedDomNode;
}

- (void)setAnimationTimer:(NSTimer *)anAnimationTimer
{
	[anAnimationTimer retain];
	if (nil != myAnimationTimer)
	{
		[myAnimationTimer invalidate];		// invalidate the timer before releasing; needed?
		[myAnimationTimer release];
	}
	myAnimationTimer = anAnimationTimer;
}

- (NSMutableDictionary *)contextElementInformation
{
	return myContextElementInformation;
}

- (void)setContextElementInformation:(NSMutableDictionary *)aContextElementInformation
{
	[aContextElementInformation retain];
	[myContextElementInformation release];
	myContextElementInformation = aContextElementInformation;
}

- (BOOL)selectedDOMRangeIsEditable
{
	DOMRange *selectedRange = [oWebView selectedDOMRange];
	if ( nil == selectedRange )
	{
		return NO;
	}
	DOMHTMLElement *selectableNode = [self selectableNodeEnclosing:[selectedRange startContainer]];
	
	return ( (nil != selectableNode) && [self isEditableElement:selectableNode] );
}

- (BOOL)selectedDOMRangeIsEditableButNotRawHtml
{
	DOMRange *selectedRange = [oWebView selectedDOMRange];
	if ( nil == selectedRange )
	{
		return NO;
	}
	DOMHTMLElement *selectableNode = [self selectableNodeEnclosing:[selectedRange startContainer]];
    
    BOOL nodeContainsKHtml = NO;
    if ( (nil != selectableNode) && [[selectableNode idName] hasPrefix:@"k-"] )
    {
        NSString *classes = [selectableNode className];
        if ( NSNotFound != [classes rangeOfString:@"kHtml"].location )
        {
            nodeContainsKHtml = YES;
        }
    }        
	
    BOOL result = ( (nil != selectableNode) && [self isEditableElement:selectableNode] && !nodeContainsKHtml );
	return result;
}

#pragma mark -
#pragma mark WebFrameLoadDelegate Methods

- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)aWindowScriptObject
{
	[self setWindowScriptObject:aWindowScriptObject];	// keep this around so we can clear the value later
	
	//related to webkit  bugzilla 6152 ... ggaren may work on it
	
	// work-around for retain loop: we make a proxy that doesn't retain self
	// Only create the helper once, though.
	//COMMMENTING OUT CHECK FOR NOW -- PROBLEM WITH CONVERSE, removeWebScriptKey:@"helper", WE GOT A CRASH AFTER APPLYING THIS CHANGE.
//	id currentHelper = [aWindowScriptObject valueForKey:@"helper"];
//	if (nil == currentHelper || ![currentHelper isKindOfClass:[KTHelper class]])
//	{
		KTHelper *helper = [[KTHelper alloc] initWithWindowController:self];
		[aWindowScriptObject setValue:helper forKey:@"helper"];
		[helper release];
//	}
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
	// Only report feedback for the main frame.
	if (frame == [sender mainFrame]){
		// Reset resource status variables
		//	  resourceCount = 0;
		//	  resourceCompletedCount = 0;
		//	  resourceFailedCount = 0;
	}
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
	// Only report feedback for the main frame.
	if (frame == [sender mainFrame])
	{
		[self setWebViewTitle:title];
		//		[self updateWindow];
	}
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if (frame == [oWebView mainFrame])
	{
		if (nil != myAnimationCoverWindow)	// Are we working on a transition animation?
		{
			if (nil== myAnimationTimer || ![myAnimationTimer isValid])	// not already started by the delayed perform?
			{
				[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startAnimation:) object:nil];
				[self startAnimation:nil];
			}
			else	// Animation already started, so just "fix" the final image mid-animate
			{
				NSRect r = [oWebView bounds];
				NSBitmapImageRep *bitmap = [oWebView bitmapImageRepForCachingDisplayInRect:r];
				[oWebView cacheDisplayInRect:r toBitmapImageRep:bitmap];
				// DON'T USE THIS "OLD" TECHNIQUE -- IT DOESN'T SEEM TO CAPTURE THE *NEW* IMAGE!
				//[oWebView lockFocus];
				//NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:r];
				//[oWebView unlockFocus];
				
				CIImage *destImage = [[[CIImage alloc] initWithBitmapImageRep:bitmap] autorelease];
				[myTransitionFilter setValue:destImage forKey:@"inputTargetImage"];
			}
		}
		//		if ([defaults boolForKey:@"ShowSourceDrawer"])
		{
			WebDataSource *dataSource = [frame dataSource];
			id <WebDocumentRepresentation>	representation = [dataSource representation];
			NSString *source = NSLocalizedString(@"No Source Available", @"Warning when we cannot load HTML source of a web page");
			if ([representation canProvideDocumentSource])
			{
				source = [representation documentSource];
			}
			
			[self setHTMLSource:source];
		}
		
		[self processEditableElementsFromDoc:[frame DOMDocument]];
		
		[self setHilite:YES onHTMLElement:mySelectedPageletHTMLElement];
		// need to do this with inline images too probably
		
		// Restore scroll position
		
		NSScrollView *scrollView=firstScrollView(oWebView);
		if (scrollView && myHasSavedVisibleRect) {
			[[scrollView documentView] scrollRectToVisible:myDocumentVisibleRect];
			myHasSavedVisibleRect=NO;
		}
		
		// Make sure webview is visible now.
		[oSourceScrollView setHidden:YES];
		[oWebView setHidden:NO];
	}
}

#pragma mark -
#pragma mark WebViewPolicyDelegate


- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request
		  frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
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
	else if([scheme isEqualToString:@"applewebdata"])
	{
		KTPage *thePage = [self pageFromURLPath:[url path]];
		if (nil == thePage)
		{
			[KTSilencingConfirmSheet alertWithWindow:[self window]
										silencingKey:@"shutUpFakeURL"
											   title:NSLocalizedString(@"Non-Page Link",@"title of alert")
											  format:NSLocalizedString
				(@"You clicked on a link that would open a page that Sandvox cannot directly display.\n\n\t", @""),
				[url path]];		
		}
		else
		{
			NSMutableArray *toExpandArray = [NSMutableArray array];
			
			KTPage *toExpand = thePage;
			int row = [oSiteOutline rowForItem:toExpand];
			while (row < 0)
			{
				// couldn't find in site outline, add parent
				toExpand = [toExpand parent];
				[toExpandArray addObject:toExpand];
				row = [oSiteOutline rowForItem:toExpand];
			}
			// Now we have list of items to expand.	Go backward through that list, expanding farthest ancestor first
			NSEnumerator *theEnum = [toExpandArray reverseObjectEnumerator];
			
			while (nil != (toExpand = [theEnum nextObject]) )
			{
				[oSiteOutline expandItem:toExpand];
			}
			
			// Now we should have our row
			row = [oSiteOutline rowForItem:thePage];
			if (row >= 0)
			{
				[oSiteOutline selectRow:row byExtendingSelection:NO];
			}
			else
			{
				NSBeep();
			}
		}
		// don't continue loading this url in our view:
		[listener ignore];
	}
	else if([scheme isEqualToString:@"file"] )
	{
		[listener ignore];
	}
	else {
		// do the default stuff for other schemes:
		[listener use];
	}
}

- (KTPage *)pageFromURLPath:(NSString *)aPath
{
	KTPage *result = nil;
	
	// skip media objects ... starting or containing Media if it's not a request in the main frame
	if ( NSNotFound == [aPath rangeOfString:kKTMediaPath].location )
	{
		int whereTilde = [aPath rangeOfString:kKTPageIDDesignator options:NSBackwardsSearch].location;	// special mark internally to look up page IDs
		if (NSNotFound != whereTilde)
		{
			NSString *idString = [aPath substringFromIndex:whereTilde+[kKTPageIDDesignator length]];
			NSManagedObjectContext *context = [[self document] managedObjectContext];
			result = [context pageWithUniqueID:idString];
		}
		else if ([aPath hasSuffix:@"/"])
		{
			result = (KTPage *)[[self document] root];
		}
	}
	return result;
}


#pragma mark -
#pragma mark WebUIDelegate Methods

- (KTAbstractPlugin *) selectableItemAtPoint:(NSPoint)aPoint itemID:(NSString **)outIDString
{
	KTAbstractPlugin *result = nil;
	NSDictionary *item = [oWebView elementAtPoint:aPoint];
	DOMNode *aNode = [item objectForKey:WebElementDOMNodeKey];
	NSString *theID = nil;
	DOMHTMLElement *selectedNode = [self selectableNodeEnclosing:aNode];
	
	if (nil != selectedNode)
	{
		theID = [selectedNode idName];
		if (nil != theID)
		{
			result = [self itemForDOMNodeID:theID];
		}
	}
	if (nil != outIDString)
	{
		*outIDString = theID;
	}
	return result;
}

/*!	Called if you click on a pagelet owned by another page.	 Selects that pagelet and its enclosing page!
Node was retained so that it lives to this invocation!
*/
- (void)selectOwnerPageAndPageletRetainedElement:(DOMHTMLElement *)anElement
{
	KTPagelet *pagelet = [self pageletEnclosing:anElement];
	
	int row = [oSiteOutline rowForItem:[pagelet page]];
	if (row >= 0)
	{
		[oSiteOutline selectRow:row byExtendingSelection:NO];
		[self setSelectedPageletHTMLElement:anElement];
		//		[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:pagelet];
	}
	else
	{
		NSLog(@"couldn't select containing page in outline view");
		NSBeep();
	}
	[anElement autorelease];		// go ahead and let it go now
}

/*!	This is my own delegate method for dealing with a click.  Store the selected ID away, and flash the rectangle of what was clicked, using an overlay window so we don't interfere with the WebView.

Note that this method is called AFTER the webview handles the click.
*/
- (void)webView:(WebView *)sender singleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags
{
	// if the webview takes a click, automatically close the link panel
	if ( [oLinkPanel isVisible] )
	{
		[self finishLinkPanel:nil];
	}
	
	[self setLastClickedPoint:aPoint];
	
	NSDictionary *item = [oWebView elementAtPoint:aPoint];
	DOMNode *aNode = [item objectForKey:WebElementDOMNodeKey];
	
	if (nil == aNode)		// nothing found, no point in continuing
	{
		// Be sure any pagelet and inline image is deselected
		[self setSelectedPageletHTMLElement:nil];
		[self setSelectedPagelet:nil];
		[self selectInlineIMGNode:nil container:nil];
		return;
	}
	
	if ([[aNode nodeName] isEqualToString:@"IMG"] && ![[aNode className] isEqualToString:kKTInternalImageClassName])
	{
		DOMHTMLElement *selectedNode = [self selectableNodeEnclosing:aNode];
		
		// did we click on an image in a block of editable text, or on a photo (like a photo page/pagelet)
		if (nil != selectedNode && ([self isEditableElement:selectedNode] || [DOMNode isImageFromDOMNodeClass:[selectedNode className]]) )
		{
			NSString *theID = [selectedNode getAttribute:@"id"];
			id itemToEdit = [self itemForDOMNodeID:theID];
			if (nil != itemToEdit)
			{
				// we're here for instance if we clicked on an image in a pagelet or photo page
				
				id container = [itemToEdit valueForKey:@"container"];
				
				NSString *classes = [selectedNode className];
				if ( (NSNotFound != [classes rangeOfString:@"kBlock"].location) ||	nil == container )		// empty container means inline
				{
					[self selectInlineIMGNode:aNode container:itemToEdit];
					[self setSelectedPageletHTMLElement:nil];
					[self setSelectedPagelet:nil];
				}
				else if ([container isKindOfClass:[KTPage class]])	// image in a page, select that detail.	(An image in a pagelet has to put image inspector along with pagelet)
				{
					// clicked on an image in a page
					[self setSelectedPageletHTMLElement:nil];
					[self setSelectedPagelet:nil];
					[self selectInlineIMGNode:nil container:nil];	// deselect any inline image
					[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:itemToEdit];
				}
				else if ([container isKindOfClass:[KTPagelet class]])	// image in a pagelet, select that pagelet
				{
					[self setSelectedPageletHTMLElement:selectedNode];
					// TODO: I need to be saving the pagelet, and then figuring out the pagelet element, and saving that, so it will survive across reloads!
					
					[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:container];
				}
				else
				{
					LOG((@"Clicked on an image, but not doing anything special"));
				}
			}
		}
		else
		{
			LOG((@"You clicked on something else"));	
		}
	}
	else
	{
		[self selectInlineIMGNode:nil container:nil];	// deselect any inline image regardless of what's selected now
		
		// Now see if this is a click anywhere in a pagelet
		DOMHTMLElement *pageletElement = [self pageletElementEnclosing:aNode];
		
		if (nil != pageletElement)
		{
			KTPagelet *pagelet = [self pageletEnclosing:aNode];
			
			KTPage *selectedPage = [self selectedPage];
			if ( [[selectedPage valueForKeyPath:@"callouts"] containsObject:pagelet]
				 || [[selectedPage valueForKeyPath:@"sidebars"] containsObject:pagelet])
			{				
				[self setSelectedPageletHTMLElement:pageletElement];
				// TODO: I need to be saving the pagelet, and then figuring out the pagelet element, and saving that, so it will survive across reloads!
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:pagelet];
			}
			else if (nil != pagelet)
			{
				[self setSelectedPageletHTMLElement:nil];
				[self setSelectedPagelet:nil];
				NSString *plugin = [[pagelet bundle] pluginName];
				if (nil == plugin) NSLog(@"Nil KTPluginName: %@", [pagelet bundle]);
				NSString *desc = [NSMutableString stringWithString:plugin];
				NSString *titleHTML = [pagelet titleHTML];
				if (nil != titleHTML && ![titleHTML isEqualToString:@""] && ![titleHTML isEqualToString:[[pagelet bundle] pluginUntitledName]])
				{
					desc = [NSString stringWithFormat:NSLocalizedString(@"%@ \"%@\"", @"format to show type of pagelet and its title, e.g. RSS Feed 'Cat Daily Digest'"),
						desc, [titleHTML flattenHTML]];
				}
				KTPage *owningPage = [pagelet page];
				
				NSString *containingPageDescription = [owningPage isRoot]
					? NSLocalizedString(@"the home page",@"fragment describing homepage")
					: [NSString stringWithFormat:NSLocalizedString(@"an enclosing container page, \"%@\"",@"fragment describing a particular page"), [owningPage titleText]];
				
				[[self confirmWithWindow:[self window]
							silencingKey:@"ShutUpCantSelect"
							   canCancel:YES OKButton:NSLocalizedString(@"Select",@"Button title")
								 silence:NSLocalizedString(@"Always select containing page", @"")
								   title:NSLocalizedString(@"Cannot Select Pagelet From This Page",@"alert title (capitalized)")
								  format:NSLocalizedString(@"The item you clicked on, %@, is copied from %@.	 Please select that page to edit this pagelet.",@""),
					desc, containingPageDescription]
					selectOwnerPageAndPageletRetainedElement:((DOMHTMLElement *)[pageletElement retain])];
				
				//				[KTSilencingConfirmSheet alertWithWindow:[self window]
				//											silencingKey:@"ShutUpCantSelect"
				//													 title:NSLocalizedString(@"Cannot Select Pagelet from This Page", @"")
				//													format:NSLocalizedString(@"The item you clicked on, %@, is copied from an enclosing container page, \"%@\".	 Please select that page to edit this pagelet.",@""), desc, containingPageTitleText];
			}
		}
		else	// clicked somewhere else ...
		{
			[self setSelectedPageletHTMLElement:nil];	// not a pagelet, deselect any pagelet
			[self setSelectedPagelet:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:[self selectedPage]];

			//DOMHTMLElement *node = [self selectableNodeEnclosing:aNode];
			// LOG((@"Clicked in this node:%@", ([node respondsToSelector:@selector(outerHTML)] ? [node outerHTML] : node) ));

			// see if we need to clear the inlineImage inspector
			if ( nil != [self selectedInlineImageElement]
				 && [[[KTInfoWindowController sharedInfoWindowControllerWithoutLoading] currentSelection] 
					isEqual:[self selectedInlineImageElement]] )
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification
																	object:[[self selectedInlineImageElement] page]];			
			}
			else
			{

			}
		}
	}
}

- (void)selectInlineIMGNode:(DOMNode *)aNode container:(KTAbstractPlugin *)aContainer
{
	if (nil != aNode)
	{
		KTInlineImageElement *element = [KTInlineImageElement inlineImageElementWithDOMNode:aNode 
																				  container:aContainer 
																					   page:[self selectedPage] 
																		  webViewController:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:element];
	}
}

/*!	Open up editor window.	I may want to have a menu action for dealing with this so we don't need a double-click,
but the only trick is -- how to display a highlight?
*/

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	return nil;
}

- (void)webViewShow:(WebView *)sender
{
}



- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(unsigned int)modifierFlags
{
	if ( nil != [elementInformation valueForKey:WebElementLinkTitleKey] )
	{
		NSString *title = [elementInformation valueForKey:WebElementLinkTitleKey];
		[self setStatusField:title];
	}
	else if ( nil != [elementInformation valueForKey:WebElementLinkURLKey] )
	{
		NSURL *URL = [elementInformation valueForKey:WebElementLinkURLKey];
		NSString *urlString = @"";
		if ([[URL scheme] isEqualToString:@"applewebdata"])
		{
			KTPage *linkedPage = [self pageFromURLPath:[URL path]];
			if (nil != linkedPage)
			{
				if ( [linkedPage isRoot] )
				{
					urlString = NSLocalizedString(@"Home", "Home Page");
				}
				else
				{
					urlString = [linkedPage titleText];
				}
			}
			else
			{
				urlString = [[URL path] lastPathComponent];
			}
		}
		else
		{
			urlString = [URL absoluteString];
		}
		if ( [[URL scheme] isEqualToString:@"mailto"] )
		{
			[self setStatusField:urlString];
		}
		else if ( [[URL scheme] isEqualToString:@"media"] )
		{
			[self setStatusField:NSLocalizedString(@"On published site, clicking on image will view full-size image",@"")];
		}
		else
		{
			[self setStatusField:[NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"Go to", "Go to (followed by URL)"), urlString]];
		}
	}
	else if ( (nil != [elementInformation valueForKey:@"WebElementImageAltString"]) && ![[elementInformation valueForKey:@"WebElementImageAltString"] isEqualToString:@""] )
	{
		[self setStatusField:[NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"Image ", "Image "), [elementInformation valueForKey:@"WebElementImageAltString"]]];
	}
	else
	{
		[self setStatusField:@""];
	}
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)elementInformation defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray *array = [NSMutableArray array];
	
	//LOG((@"element ctrl-clicked on: %@", elementInformation));
	
	// context has changed, first update base info
	[self setContextElementInformation:[[elementInformation mutableCopy] autorelease]];
	
	BOOL elementIsSelected = [[elementInformation valueForKey:WebElementIsSelectedKey] boolValue];
	
	if ( nil != [elementInformation valueForKey:@"WebElementDOMNode"] )
	{
		DOMNode *node = [elementInformation valueForKey:@"WebElementDOMNode"];
		DOMHTMLElement *selectedNode = [self selectableNodeEnclosing:node];
		
		// first, if the element is editable and linkable, add a Create/Edit Link... item
		if ( elementIsSelected
			 && [self isEditableElement:selectedNode]
			 && [DOMNode isLinkableFromDOMNodeClass:[selectedNode className]] )
		{
			// add selectedDOMRange to elementInformation
			NSMutableDictionary *elementDictionary = [NSMutableDictionary dictionaryWithDictionary:[self contextElementInformation]];
			
			DOMRange *selectedDOMRange = [oWebView selectedDOMRange];
			if ( nil != selectedDOMRange )
			{
				[elementDictionary setObject:selectedDOMRange forKey:KTSelectedDOMRangeKey];
			}
			else
			{
				// selectedDOMRange will be nil when a pre-existing link is ctrl-clicked
				// without making a selection. in that case, assume we want to work on the entire node
				DOMDocument *document = [[selectedDOMRange startContainer] ownerDocument];
				DOMRange *range = [document createRange];
				[range selectNode:node];
				[elementDictionary setObject:range forKey:KTSelectedDOMRangeKey];
			}
			
			[self setContextElementInformation:[NSMutableDictionary dictionaryWithDictionary:elementDictionary]];
			
			// start with an Edit or Create link menuitem
			if ( nil != [elementInformation objectForKey:@"WebElementLinkURL"] )
			{
				// the selection contains a link, so let's assume we want to edit it
				NSMenuItem *editLinkItem = [[NSMenuItem alloc] initWithTitle:EDIT_LINK_MENUITEM_TITLE
																	  action:@selector(performShowLinkPanel:)
															   keyEquivalent:@""];
				[editLinkItem setRepresentedObject:nil];
				[editLinkItem setTarget:nil];
				[array addObject:editLinkItem];
				[editLinkItem release];
			}
			else
			{
				// no link included, maybe we want to add one
				NSMenuItem *createLinkItem = [[NSMenuItem alloc] initWithTitle:CREATE_LINK_MENUITEM_TITLE
																		action:@selector(performShowLinkPanel:)
																 keyEquivalent:@""];
				[createLinkItem setRepresentedObject:nil];
				[createLinkItem setTarget:nil];
				[array addObject:createLinkItem];
				[createLinkItem release];
			}
		}
		
		// next, trim the default menu items to a reasonable set and add to menu
		// if we're clicked on an Image, don't add any of the default menu
		if ( elementIsSelected
			 && ![node isKindOfClass:[DOMHTMLImageElement class]]
			 && (nil != [self contextElementInformation]) )
		{
			NSMutableArray *copyOfDefaultMenuItems = [defaultMenuItems mutableCopy];
			NSEnumerator *e = [copyOfDefaultMenuItems objectEnumerator];
			NSMenuItem *menuItem;
			while ( menuItem = [e nextObject] )
			{
				BOOL shouldRemove = NO;
				
				NSString *actionString = NSStringFromSelector([menuItem action]);
				if ( [actionString isEqualToString:@"reload:"] )
				{
					shouldRemove = YES;
				}
				else if ( [actionString isEqualToString:@"submenuAction:"] )
				{
					// remove all submenus except Spelling and Find
					// this is a bit of a hack since it depends on string comparisons
					NSString *spellingTitle = NSLocalizedString(@"Spelling", "Spelling MenuItem"); // must match WebKit's
					NSString *findTitle = NSLocalizedString(@"Find", "Find MenuItem"); // must match WebKit's
					if ( ![[menuItem title] isEqualToString:spellingTitle]
						 && ![[menuItem title] isEqualToString:findTitle] )
					{
						shouldRemove = YES;
					}
				}
				
				if ( shouldRemove )
				{
					[copyOfDefaultMenuItems removeObject:menuItem];
				}
			}
			if ( [copyOfDefaultMenuItems count] > 0 )
			{
				if ( [array count] > 0 )
				{
					[array addObject:[NSMenuItem separatorItem]];
				}
				[array addObjectsFromArray:copyOfDefaultMenuItems];
			}
		}
		
		// is element a pagelet?
		KTPagelet *pagelet = [self pageletEnclosing:node];
		if ( nil != pagelet )
		{
			if ( [array count] > 0 )
			{
				[array addObject:[NSMenuItem separatorItem]];
			}
			
			KTPage *selectedPage = [self selectedPage];
			if ( [[selectedPage valueForKeyPath:@"callouts"] containsObject:pagelet]
				 || [[selectedPage valueForKeyPath:@"sidebars"] containsObject:pagelet])
			{
				[self setSelectedPagelet:pagelet];
				
				NSMenuItem *deletePageletItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Delete Pagelet", "Delete Pagelet MenuItem")
																		   action:@selector(deletePagelets:)
																	keyEquivalent:@""];
				[deletePageletItem setRepresentedObject:nil];
				[deletePageletItem setTarget:nil];
				[array addObject:deletePageletItem];
				[deletePageletItem release];
				
				// if on selectedPage's calloutsList, put up Move to Sidebar
				NSMenuItem *moveMenuItem = nil;
				if ( [[selectedPage valueForKeyPath:@"callouts"] containsObject:pagelet] 
                     && [selectedPage includeSidebar] )
				{
					moveMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Move to Sidebar", "Move to Sidebar MenuItem")
															  action:@selector(movePageletToSidebar:)
													   keyEquivalent:@""];
					[moveMenuItem setTarget:selectedPage];
					[moveMenuItem setRepresentedObject:pagelet];
				}
				// else, if on selectedPage's sidebarsList, put up Move to Callout
				else if ( [[selectedPage valueForKeyPath:@"sidebars"] containsObject:pagelet] 
                          && [selectedPage includeCallout] )
				{
					moveMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Move to Callout", "Move to Callout MenuItem")
															  action:@selector(movePageletToCallouts:)
													   keyEquivalent:@""];
					[moveMenuItem setTarget:selectedPage];
					[moveMenuItem setRepresentedObject:pagelet];
				}
				if (nil != moveMenuItem)
				{
					[array addObject:moveMenuItem];
					[moveMenuItem release];
				}
			}
			else	// show in menu reason why pagelet can't be manipulated
			{
				KTPage *owningPage = [pagelet page];
				
				NSString *menuTitle = [owningPage isRoot]
					? NSLocalizedString(@"Pagelet owned by home page",
										@"menu item showing that pagelet canot be manipulated")
					: [NSString stringWithFormat:NSLocalizedString(@"Pagelet owned by page \"%@\"",
																   @"menu item showing that pagelet canot be manipulated"),
						[owningPage titleText]];
				NSMenuItem *noOpPageletItem
					= [[NSMenuItem alloc]
						initWithTitle:menuTitle
							   action:nil
						keyEquivalent:@""];
				[noOpPageletItem setRepresentedObject:nil];
				[noOpPageletItem setTarget:nil];
				[array addObject:noOpPageletItem];
				[noOpPageletItem release];
			}
		}
		
		// See if it's summary
		
		if (nil != selectedNode)
		{
			NSString *theID = [selectedNode idName];
			if (nil != theID)
			{
				NSString *propName = [self propertyNameForDOMNodeID:theID];
				if ([propName isEqualToString:@"summaryHTML"])
				{
					if ( [array count] > 0 )
					{
						[array addObject:[NSMenuItem separatorItem]];
					}
					KTPage *theSummarizedPage = [self itemForDOMNodeID:theID];
					
					NSMenuItem *theSummaryMenuItem = nil;
					SEL theAction;
					NSString *menuTitle = nil;
					if ([theSummarizedPage isSummaryOverridden])
					{
						menuTitle = NSLocalizedString(@"Remove Custom Summary of Page...",@"contextual menu item");
						theAction = @selector(unOverrideSummary:);
					}
					else
					{
						menuTitle = NSLocalizedString(@"Custom Summary for Index",@"contextual menu item");
						theAction = @selector(overrideSummary:);
					}
					theSummaryMenuItem = [[NSMenuItem alloc] initWithTitle:menuTitle
																	action:theAction
															 keyEquivalent:@""];
					[theSummaryMenuItem setRepresentedObject:nil];
					[theSummaryMenuItem setTarget:theSummarizedPage];
					[array addObject:theSummaryMenuItem];
					[theSummaryMenuItem release];
				}
			}
		}
	}	
	
	return [NSArray arrayWithArray:array];
}

/*!
@method webView:willPerformDragDestinationAction:forDraggingInfo:
 @abstract Informs that WebView will perform a drag destination action
 @param webView The WebView sending the delegate method
 @param action The drag destination action
 @param draggingInfo The dragging info of the drag
 @discussion This method is called after the last call to webView:dragDestinationActionMaskForDraggingInfo: after something is dropped on a WebView.
 This method informs the UI delegate of the drag destination action that WebView will perform.
 */
- (void)webView:(WebView *)inWebView
willPerformDragDestinationAction:(WebDragDestinationAction)action
forDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	//LOG((@"%@, %d %@", NSStringFromSelector(_cmd), action, draggingInfo));
	
	// Dragging location is in window coordinates.
	// location is converted to webview coordinates
	NSPoint location = [oWebView convertPoint:[draggingInfo draggingLocation] fromView:nil];
	NSDictionary *item = [oWebView elementAtPoint:location];
	DOMNode *aNode = [item objectForKey:WebElementDOMNodeKey];
	
	DOMHTMLElement *selectedNode = [self selectableNodeEnclosing:aNode];
	if (nil != selectedNode)
	{
		(void) [self setEditingPropertiesFromSelectedNode:selectedNode];
	}
	else
	{
		NSLog(@"Unable to find selectable node enclosing %@", aNode);
	}
}

- (void)webView:(WebView *)sender willPerformDragSourceAction:(WebDragSourceAction)action
	  fromPoint:(NSPoint)point
 withPasteboard:(NSPasteboard *)pasteboard
{
	//LOG((@"%@, %d %@", NSStringFromSelector(_cmd), action, NSStringFromPoint(point)));
}

- (unsigned)webView:(WebView *)inWebView dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	// NSLog(@"%@, %@", NSStringFromSelector(_cmd), draggingInfo);	// caution logging -- it's called a lot!
	return WebDragDestinationActionAny;
}

- (unsigned)webView:(WebView *)inWebView dragSourceActionMaskForPoint:(NSPoint)inPoint
{
	//LOG((@"%@ %@", NSStringFromSelector(_cmd), NSStringFromPoint(inPoint)));
	return WebDragSourceActionAny;
}

#pragma mark -
#pragma mark WebUIDelegate - Support

/*!	Find the node, if any, that has a class of "pagelet" in its class name

class has pagelet, ID like k-###	(the k- is to be recognized elsewhere)
*/


- (DOMHTMLElement *)pageletElementEnclosing:(DOMNode *)aNode;
{
	DOMHTMLElement *foundDiv = nil;
	
	if ([aNode isKindOfClass:[DOMCharacterData class]])
	{
		aNode = [aNode parentNode];	// get up to the element
	}
	while (nil != aNode && [aNode isKindOfClass:[DOMHTMLElement class]] && ![aNode isKindOfClass:[DOMHTMLBodyElement class]])
	{
		if (nil == foundDiv)
		{
			NSString *theClass = [aNode className];
			NSArray *classes = [theClass componentsSeparatedByWhitespace];
			if ([classes containsObject:@"pagelet"])
			{
				foundDiv = (DOMHTMLElement *)aNode;				  // save for later
				break;
			}
		}
		// Now continue up the chain to the parent.
		aNode = [aNode parentNode];
	}
	return foundDiv;
}

- (KTPagelet *)pageletEnclosing:(DOMNode *)aNode;
{
	KTPagelet *result = nil;
	DOMHTMLElement *foundDiv = [self pageletElementEnclosing:aNode];
	
	if (nil != foundDiv)
	{
		NSString *divID = [foundDiv idName];
		
		// NB: we expect a 1 character prefix on divID (the pagelet DIV)
		// which we have to strip before passing to Core Data
		// pagelet DIVs are built from the various pagelet templates
		divID = [divID substringFromIndex:2];
		
		// Fetch the pagelet object
		// peform fetch
		NSManagedObjectContext *context = [[self document] managedObjectContext];
		NSError *fetchError = nil;
		NSArray *fetchedObjects = [context objectsWithEntityName:@"Pagelet"
													   predicate:[NSPredicate predicateWithFormat:@"uniqueID like %@", divID]
														   error:&fetchError];	
		// extract result
		if ( (nil != fetchedObjects) && ([fetchedObjects count] == 1) )
		{
			result = [fetchedObjects objectAtIndex:0];
		}
	}
	return result;
}


/*!	Determines what node, if any, is "selectable" -- e.g. editable text or a photo element.
To find out of it's editable, try
[self isEditableElement:selectedNode]
*/
- (DOMHTMLElement *)selectableNodeEnclosing:(DOMNode *)aNode
{
	DOMHTMLElement *result = nil;
	
	if ([aNode isKindOfClass:[DOMCharacterData class]])
	{
		aNode = [aNode parentNode];	// get up to the element
	}
	while (nil != aNode && [aNode isKindOfClass:[DOMHTMLElement class]] && ![aNode isKindOfClass:[DOMHTMLBodyElement class]])
	{
		// If we have an ID k-_______ then we found it
		
		if (nil == result)
		{
			NSString *idValue = [((DOMHTMLElement *)aNode) getAttribute:@"id"];
			if ([idValue hasPrefix:@"k-"])
			{
				result = (DOMHTMLElement *)aNode;				// save for later
				break;
			}
		}
		// Now continue up the chain to the parent.
		aNode = [aNode parentNode];
	}
	return result;
}

#pragma mark in-line link editor methods

- (NSWindow *)linkPanel { return oLinkPanel; }

- (void)linkPanelDidLoad
{
	[oLinkView setDelegate:self];
	// tweak the look
	[oLinkControlsBox setDrawsGradientBackground:NO];
	//[oLinkControlsBox setGradientStartColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];
	//[oLinkControlsBox setGradientEndColor:[NSColor colorWithCalibratedWhite:0.82 alpha:1.0]];
	[oLinkControlsBox setBackgroundColor:[NSColor colorWithCalibratedWhite:0.95 alpha:1.0]];
	[oLinkControlsBox setBorderColor:[NSColor lightGrayColor]];
	[oLinkControlsBox setTitleColor:[NSColor whiteColor]];
	[oLinkControlsBox setDrawsFullTitleBar:NO];
	[oLinkControlsBox setBorderWidth:1.0];
	
	[[oLinkControlsBox window] setDelegate:self];
}

- (id)userInfoForLinkSource:(KTLinkSourceView *)link
{
	return [self document];
}

- (NSPasteboard *)linkSourceDidBeginDrag:(KTLinkSourceView *)link
{
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:kKTLocalLinkPboardType] owner:self];
	[pboard setString:@"LocalLink" forType:kKTLocalLinkPboardType];
	
	return pboard;
}

- (void)linkSourceDidEndDrag:(KTLinkSourceView *)link withPasteboard:(NSPasteboard *)pboard
{
	NSDictionary *info = [self contextElementInformation];
	if (info)
	{
		// set up a link to the local page
		NSString *pageID = [pboard stringForType:kKTLocalLinkPboardType];
		if ( (pageID != nil) && ![pageID isEqualToString:@""] )
		{
			KTPage *target = [[[self document] managedObjectContext] pageWithUniqueID:pageID];
			if ( nil != target )
			{
				NSString *titleText = [target titleText];
				if ( (nil != titleText) && ![titleText isEqualToString:@""] )
				{
					[oLinkLocalPageField setStringValue:titleText];
					[oLinkDestinationField setStringValue:@""];
					[oLinkLocalPageField setHidden:NO];
					[oLinkDestinationField setHidden:YES];
					
					[info setValue:[NSString stringWithFormat:@"%@%@", kKTPageIDDesignator, pageID] forKey:@"KTLocalLink"];
					[oLinkView setConnected:YES];
					
				}
			}
		}
	}
	//	NO, DON'T CLOSE THE LINK PANEL WHEN YOU DRAG.	[oLinkPanel orderOut:self];
}

- (IBAction)performShowLinkPanel:(id)sender
{
	[self performSelector:@selector(showLinkPanel:) withObject:sender afterDelay:0.0];
}

- (IBAction)showLinkPanel:(id)sender
{
	BOOL localLink = NO;		// override if it's a local link
	NSString *theLinkString = nil;
	
	[oLinkOpenInNewWindowSwitch setState:NSOffState];
	
	// populate with context information
	NSDictionary *info = [[self contextElementInformation] retain];
	if ( nil != info )
	{
		DOMNode *node = [info objectForKey:WebElementDOMNodeKey];
		DOMRange *selectedRange = [oWebView selectedDOMRange];
		
		// set oLinkDestinationField
		NSURL *URL = [info objectForKey:WebElementLinkURLKey];
		
		if ( nil != URL )
		{
			theLinkString = [URL absoluteString];
			if ([theLinkString hasPrefix:@"applewebdata:"])
			{
				theLinkString = [theLinkString lastPathComponent];
				// some absolute page link.	 Restore the leading slash
				theLinkString = [@"/" stringByAppendingString:theLinkString];
			}
			NSRange wherePageID = [theLinkString rangeOfString:kKTPageIDDesignator];
			if (NSNotFound != wherePageID.location)
			{
				[info setValue:[theLinkString lastPathComponent] forKey:@"KTLocalLink"]; // mark as local link so we preserve it
				NSString *uid = [theLinkString substringFromIndex:NSMaxRange(wherePageID)];
				KTPage *targetPage = [[[self document] managedObjectContext] pageWithUniqueID:uid];
				theLinkString = [targetPage titleText];
				localLink = YES;
			}
		}
		else if ( nil != node )
		{
			// examine selectedRange for an e-mail address
			NSString *string = [selectedRange toString];
			if ( [string isValidEmailAddress] )
			{
				theLinkString = [NSString stringWithFormat:@"mailto:%@", string];
			}
			else
			{
				// Try to populate from frontmost Safari URL
				NSURL *safariURL = nil;
				NSString *safariTitle = nil;	// someday, we could populate the link title as well!
				BOOL gotSafariURL = [NSAppleScript safariFrontmostURL:&safariURL title:&safariTitle source:nil];
				if (gotSafariURL && nil != safariURL)
				{
					theLinkString = [safariURL absoluteString];
				}
			}
		}
		
		[oLinkView setConnected:(nil != theLinkString)];
		
		if (nil == theLinkString)
		{
			theLinkString = @"";
		}
		if (localLink)
		{
			[oLinkLocalPageField setStringValue:theLinkString];
			[oLinkDestinationField setStringValue:@""];
		}
		else
		{
			[oLinkLocalPageField setStringValue:@""];
			[oLinkDestinationField setStringValue:[theLinkString urlDecode]];
		}
		[oLinkLocalPageField setHidden:!localLink];
		[oLinkDestinationField setHidden:localLink];
		
		// set oLinkOpenInNewWindowSwitch
		if ( nil != [info objectForKey:WebElementDOMNodeKey] )
		{
			DOMNode *parentNode = [[info objectForKey:WebElementDOMNodeKey] parentNode];
			if ( [parentNode isKindOfClass:[DOMHTMLAnchorElement class]] )
			{
				NSString *target = [(DOMHTMLAnchorElement *)parentNode target];
				if ( [target isEqualToString:@"_blank"] )
				{
					[oLinkOpenInNewWindowSwitch setState:NSOnState];
				}
			}
		}
		
		// set top left corner of window to top of selectedTextRect in screen coordinates
		NSPoint topLeftCorner = [self linkPanelTopLeftPointForSelectionRect:mySelectionRect];
		NSPoint convertedWindowOrigin = [[oWebView window] convertBaseToScreen:topLeftCorner];
		[oLinkPanel setFrameTopLeftPoint:convertedWindowOrigin];
		
		// make it a child window, set focus on the link, and display
		[[oWebView window] addChildWindow:oLinkPanel ordered:NSWindowAbove];
		[oLinkPanel makeKeyAndOrderFront:nil]; // we do makeKey so that textfield gets focus
	}
	else
	{
		//[NSException raise:kKTGenericDocumentException format:@"Unable to show link panel: no context element information."];
		NSLog(@"Unable to show link panel: no context element information.");
	}
	[info release];
}

- (NSString *)removeLinkWithContextInformation:(NSDictionary *)info
{
	// find the common ancestor
	DOMRange *selectedRange = [info objectForKey:KTSelectedDOMRangeKey];
	DOMNode *ancestor = [selectedRange commonAncestorContainer];
	// examine its children for anchor elements
	NSMutableArray *anchors = [NSMutableArray arrayWithArray:[ancestor anchorElements]];
	// if the ancestor has no anchors, see if its parent is an anchor
	if ( (nil != anchors) && ([anchors count] == 0) )
	{
		DOMNode *ancestorParent = [ancestor parentNode];
		if ( [ancestorParent isKindOfClass:[DOMHTMLAnchorElement class]] )
		{
			[anchors addObject:ancestorParent];
		}
	}
	// if more than 1, you have a contextual menu problem, there should never be more than 1
	if ( (nil != anchors) && ([anchors count] == 1) )
	{
		// have the anchor's parent replace the anchor with the anchor's child
		DOMHTMLAnchorElement *anchor = [anchors objectAtIndex:0];
		DOMNode *anchorParent = [anchor parentNode];
		if ( [anchor hasChildNodes] )
		{
			DOMNode *child = [anchor firstChild];
			
			[[DOMNode class] node:anchorParent replaceChild:child :anchor];
		}
		else
		{
			// not sure how it would be selectable without child text...
			[[DOMNode class] node:anchorParent removeChild:anchor];
		}
		return NSLocalizedString(@"Remove Link","ActionName: Remove Link");
	}
	else
	{
		LOG((@"selectedRange of anchor has more than one anchor, ignoring..."));
		return nil;
	}
}

- (NSString *)editLink:(NSString *)newLink withContextInformation:(NSDictionary *)info
{
	// there is an anchor in play, find it and set its href
	DOMNode *element = [info objectForKey:WebElementDOMNodeKey];
	DOMHTMLAnchorElement *anchor = [element immediateContainerOfClass:[DOMHTMLAnchorElement class]];
	if ( nil != anchor )
	{
		NSString *target = nil;
		if ( NSOnState == [oLinkOpenInNewWindowSwitch state] )
		{
			target = @"_blank";
		}
		[[DOMHTMLAnchorElement class] element:anchor setHref:newLink target:target];
		return NSLocalizedString(@"Edit Link","ActionName: Remove Link");
	}
	else
	{
		LOG((@"unable to locate parent anchor for node: %@", element));
		return nil;
	}
}

// need to save off URL from drag and not call this until inside finish

- (NSString *)createLink:(NSString *)link withContextInformation:(NSDictionary *)info
{
	// no anchor in play, we need to add it as the selection's parent
	DOMRange *selectedRange = [info objectForKey:KTSelectedDOMRangeKey];
	DOMNode *startNode = [selectedRange startContainer];
	DOMNode *endNode = [selectedRange endContainer];
	DOMNode *parentNode = [startNode parentNode];
	
	//BOOL elementIsSelected = ([selectedRange startOffset] != [selectedRange endOffset]);
	//if ( elementIsSelected )
	if ( ![selectedRange collapsed] ) // per Graham
	{
		if ( [startNode isKindOfClass:[DOMText class]] )
		{
			// turn the selection into a new text node
			DOMText *text = [[startNode ownerDocument] createTextNode:[selectedRange toString]];
			
			// fire up a new anchor with text
			DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement *)[[startNode ownerDocument] createElement:@"a"];
			[anchor setHref:link];
			if ( NSOnState == [oLinkOpenInNewWindowSwitch state] )
			{
				[anchor setTarget:@"_blank"];
			}
			[anchor appendChild:text];				
			
			// chop the selection out of the range, alters both startNode and endNode
			(void)[selectedRange extractContents];
			
			// insert anchor
			if ( [startNode isEqual:endNode] )
			{
				// split the remainder at the start
				DOMNode *split = [(DOMText *)startNode splitText:[selectedRange startOffset]];
				
				// add the new anchor before the split
				[[DOMNode class] node:parentNode insertBefore:anchor :split];
			}
			else
			{
				// add anchor after startNode
				DOMNode *nextSibling = [startNode nextSibling];
				if ( nil != nextSibling )
				{
					[[DOMNode class] node:parentNode insertBefore:anchor :nextSibling];
				}
				else
				{
					[[DOMNode class] node:parentNode appendChild:anchor];
				}
			}
			
			// per Graham, reset selection after modifying node
			[selectedRange selectNodeContents:anchor];
			[oWebView setSelectedDOMRange:selectedRange affinity:NSSelectionAffinityDownstream];
		}				
	}
	else
	{
		if ( [startNode respondsToSelector:@selector(splitText:)] )
		{
			// no selection, insert a new node as value as text (minus URL scheme)
			NSString *urlText = nil;
			
			NSURL *URL = [NSURL URLWithString:[link encodeLegally]];
			NSString *scheme = [URL scheme];
			if ( nil != scheme )
			{
				NSRange schemeRange = [[URL absoluteString] rangeOfString:scheme];
				urlText = [[URL absoluteString] substringFromIndex:(schemeRange.length+1)];
			}
			else
			{
				urlText = [URL absoluteString];
			}
			
			// chop off any leading /s
			while ( [urlText hasPrefix:@"/"] )
			{
				urlText = [urlText substringFromIndex:1];
			}
			
			// turn it into a new text node
			DOMText *text = [[startNode ownerDocument] createTextNode:urlText];
			
			// fire up a new anchor with text
			DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement *)[[startNode ownerDocument] createElement:@"a"];
			[anchor setHref:link];
			if ( NSOnState == [oLinkOpenInNewWindowSwitch state] )
			{
				[anchor setTarget:@"_blank"];
			}
			[anchor appendChild:text];
			
			// split the DOM at the start
			DOMNode *split = [(DOMText *)startNode splitText:[selectedRange startOffset]];
			
			// add the new anchor before the split
			[[DOMNode class] node:parentNode insertBefore:anchor :split];
		}
		else
		{
			LOG((@"link panel attempting to split %@, but selectorNotRecognized!", [startNode class]));
			NSBeep();
		}
	}
	return NSLocalizedString(@"Add Link","Action Name: Add Link");
}

- (IBAction) clearLinkDestination:(id)sender;
{
	[oLinkLocalPageField setStringValue:@""];
	[oLinkDestinationField setStringValue:@""];
	[oLinkLocalPageField setHidden:YES];
	[oLinkDestinationField setHidden:NO];
	[oLinkView setConnected:NO];
	NSMutableDictionary *info = [self contextElementInformation];
	[info removeObjectForKey:@"KTLocalLink"];
}


- (void)closeLinkPanel
{
	[[oWebView window] removeChildWindow:oLinkPanel];
	[oLinkPanel close];
}

- (IBAction)finishLinkPanel:(id)sender
{
	NSString *undoActionName = nil;
	
	// per Graham, check/set flag to stop recursion
	// due to selectionDidChange: calling back into createLink:
	if ( myIsLinkPanelClosing )
	{
		return;
	}
	myIsLinkPanelClosing = YES;
	
	@try
	{
		// grab our element info
		NSDictionary *info = [self contextElementInformation];
		NSAssert((nil != info), @"contextElementInformation cannot be nil!");
		
		// have we set up a local link?
		if ( nil != [info valueForKey:@"KTLocalLink"] )
		{
			undoActionName = [self createLink:[info valueForKey:@"KTLocalLink"] withContextInformation:info];
		}
		else
		{
			NSString *value = [[oLinkDestinationField stringValue] trimFirstLine];
			value = [[value stringWithValidURLScheme]  trimFirstLine];
			
			if ( [value isEqualToString:@""]
				 || [value isEqualToString:@"http://"]
				 || [value isEqualToString:@"https://"]
				 || [value isEqualToString:@"ftp://"]
				 || [value isEqualToString:@"mailto:"] )
			{
				// empty field, remove the link
				if ( nil != [info objectForKey:WebElementLinkURLKey] )
				{
					undoActionName = [self removeLinkWithContextInformation:info];
				}
			}
			else
			{
				// check URL and refuse to close if not valid.  We call the delegate method to test value.
				if (![self control:oLinkDestinationField textShouldEndEditing:nil])
				{
					NSBeep();
					return;
				}
				
				// not empty, is there already an anchor in play?
				if ( nil != [info objectForKey:WebElementLinkURLKey] )
				{
					undoActionName = [self editLink:value withContextInformation:info];
				}
				else
				{
					undoActionName = [self createLink:value withContextInformation:info];
				}
			}
		}

		// update webview to reflect node changes
		[[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:oWebView];	
		[self setContextElementInformation:nil];
		
		// label undo last
		if ( nil != undoActionName )
		{
			[[[self document] undoManager] setActionName:undoActionName];
		}
	}
	@finally
	{
		// hide link panel
		[self closeLinkPanel];
		myIsLinkPanelClosing = NO;
	}
}

- (NSPoint)linkPanelTopLeftPointForSelectionRect:(NSRect)aSelectionRect
{
	NSWindow *window = [self window];
	
	float padding = 30; // eyeball
	float linkPanelWidth = 356; // from nib
	float windowWidth = [window frame].size.width;
	
	float linkPanelOriginX;
	float linkPanelOriginY;
	if ( mySelectionRect.size.width > 0 )
	{
		if ( (mySelectionRect.origin.x + linkPanelWidth) > windowWidth )
		{
			linkPanelOriginX = windowWidth - linkPanelWidth - padding;
		}
		else
		{
			linkPanelOriginX = mySelectionRect.origin.x;
		}
		linkPanelOriginY = mySelectionRect.origin.y;
	}
	else
	{
		if ( (myLastClickedPoint.x + linkPanelWidth) > windowWidth )
		{
			linkPanelOriginX = windowWidth - linkPanelWidth - padding;
		}
		else
		{
			linkPanelOriginX = myLastClickedPoint.x;
		}
		linkPanelOriginY = myLastClickedPoint.y;
	}
	
	return NSMakePoint(linkPanelOriginX,linkPanelOriginY);
}

- (void)windowDidEscape:(NSWindow *)aWindow
{
	if ( aWindow == oLinkPanel )
	{
		// escape was pressed, close link panel without accepting changes
		[self closeLinkPanel];
	}
}

/*! accepts drop of WebURLsWithTitlesPboardType and NSURLPboardType, in that order */
- (BOOL)acceptDropOfURLsFromDraggingInfo:(id <NSDraggingInfo>)sender
{
	NSString *URLAsString = nil;
	NSString *title = nil;
	
	NSPasteboard *pboard = [sender draggingPasteboard];
	
	if ( [[pboard types] containsObject:@"WebURLsWithTitlesPboardType"] )
	{
		NSArray *URLsWithTitles = [pboard propertyListForType:@"WebURLsWithTitlesPboardType"];
		if	( [URLsWithTitles count] > 0 )
		{
			NSArray *URLsAsStrings = [URLsWithTitles objectAtIndex:0];
			NSArray *titles = [URLsWithTitles objectAtIndex:1];
			
			// we're only taking the first one
			URLAsString = [URLsAsStrings objectAtIndex:0];
			title = [titles objectAtIndex:0];
		}
	}
	else if ( [[pboard types] containsObject:NSURLPboardType] )
	{
		NSURL *url = [NSURL URLFromPasteboard:pboard];
		URLAsString = [url absoluteString];
	}
	
	if ( (nil == URLAsString) || [URLAsString isEqualToString:@""] )
	{
		// we didn't find a useable URL string, not much we can do, bail
		NSBeep();
		return NO;
	}
	
	NSURL *theURL = [NSURL URLWithString:URLAsString];
	// filter out file:// URLs ... let webview handle it and insert any images
	if ( [[theURL scheme] isEqualToString:@"file"] )
	{
		LOG((@"dropping in a file: URL"));
		return NO;
	}

	if ( [[theURL scheme] isEqualToString:@"applewebdata"] )
	{
		NSRange wherePageID = [URLAsString rangeOfString:kKTPageIDDesignator];
		if (NSNotFound == wherePageID.location)
		{
			return NO;
		}
		URLAsString = [URLAsString substringFromIndex:wherePageID.location];	// new URL, just the page ID
	}
	
	if ( (nil == title) || [title isEqualToString:@""] )
	{
		// if no title, set it to the body of the URL, no scheme
		NSString *scheme = [theURL scheme];
		if ( nil != scheme )
		{
			NSRange schemeRange = [URLAsString rangeOfString:scheme];
			title = [URLAsString substringFromIndex:(schemeRange.length+1)];
		}
		else
		{
			title = URLAsString;
		}
	}
	
	// ok, at this point we should have some sort of useable url and title
	
	// figure out where we are in the WebHTMLView
	Class WebHTMLView = NSClassFromString(@"WebHTMLView");
	NSView *documentView = [[[oWebView mainFrame] frameView] documentView];
	NSAssert([documentView isKindOfClass:[WebHTMLView class]], @"documentView should be a WebHTMLView");
	
	// determine dragCaretDOMRange (DOMRange, of 0 length, where drop will go, between chars)
	id bridge = [documentView _bridge];
	DOMRange *dragCaretDOMRange = nil;
	if ([bridge respondsToSelector:@selector(dragCaretDOMRange)])
	{
		dragCaretDOMRange = (DOMRange *)[bridge dragCaretDOMRange];
	}
	
	// get our currently selected range
	DOMRange *selectedDOMRange = [oWebView selectedDOMRange];
	
	// if selectedDOMRange is nil, insert a new text node at caretPosition
	if ( nil == selectedDOMRange )
	{
		[self insertText:title href:URLAsString inRange:dragCaretDOMRange atPosition:[dragCaretDOMRange startOffset]];
		[[[self document] undoManager] setActionName:NSLocalizedString(@"Insert Link","Action Name: Insert Link")];
		return YES;
	}
	
	// no, we have a selection, do some range checking
	short startToStart = [selectedDOMRange compareBoundaryPoints:DOM_START_TO_START :dragCaretDOMRange];
	short endToEnd = [selectedDOMRange compareBoundaryPoints:DOM_END_TO_END :dragCaretDOMRange];
	// -1 = A is before B
	//	 1 = A is after B
	
	// if selectedDOMRange contains dragCaretDOMRange, change href of selection
	if ( (startToStart == -1) && (endToEnd == 1) ) // this appears to be the correct answer via testing
	{
		[self insertHref:URLAsString inRange:selectedDOMRange];
		// maybe change this if a link were already there?
		[[[self document] undoManager] setActionName:NSLocalizedString(@"Insert Link","Action Name: Insert Link")];
		return YES;
	}
	
	// otherwise, insert a new text node at caretPosition
	else
	{
		long caretPosition = [dragCaretDOMRange startOffset];
		[self insertText:title href:URLAsString inRange:dragCaretDOMRange atPosition:caretPosition];
		[[[self document] undoManager] setActionName:NSLocalizedString(@"Insert Link","Action Name: Insert Link")];
		return YES;
	}
	
	// shouldn't get here
	return NO;
}

// these methods share a bunch of code with the link panel link creation and should be refactored

- (void)insertHref:(NSString *)aURLAsString inRange:(DOMRange *)aRange
{
	//LOG((@"insertHref:%@ inRange:%@", aURLAsString, aRange));
	DOMNode *startNode = [aRange startContainer];
	DOMNode *endNode = [aRange endContainer];
	DOMNode *parentNode = [startNode parentNode];
	
	if ( [startNode isKindOfClass:[DOMText class]] )
	{
		// turn the selection into a new text node
		DOMText *text = [[startNode ownerDocument] createTextNode:[aRange toString]];
		
		// fire up a new anchor with text
		DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement *)[[startNode ownerDocument] createElement:@"a"];
		[anchor setHref:aURLAsString];
		[anchor appendChild:text];				
		
		// chop the selection out of the range, alters both startNode and endNode
		(void)[aRange extractContents];
		
		// insert anchor
		if ( [startNode isEqual:endNode] )
		{
			// split the remainder at the start
			DOMNode *split = [(DOMText *)startNode splitText:[aRange startOffset]];
			
			// add the new anchor before the split
			[[DOMNode class] node:parentNode insertBefore:anchor :split];
		}
		else
		{
			// add anchor after startNode
			DOMNode *nextSibling = [startNode nextSibling];
			if ( nil != nextSibling )
			{
				[[DOMNode class] node:parentNode insertBefore:anchor :nextSibling];
			}
			else
			{
				[[DOMNode class] node:parentNode appendChild:anchor];
			}
		}
	}	
	else
	{
		NSBeep();
		LOG((@"insertHref:inRange: DOMRange does not contain a useable DOMText!"));
	}
	
}

- (void)insertText:(NSString *)aTextString href:(NSString *)aURLAsString inRange:(DOMRange *)aRange atPosition:(long)aPosition
{
	//LOG((@"insertText:%@ href:%@ inRange:%@ atPosition:%l", aTextString, aURLAsString, aRange, aPosition));
	// make sure we're looking at a useable node
	DOMNode *startNode = [aRange startContainer];
	if ( [startNode respondsToSelector:@selector(splitText:)] )
	{
		// turn aTextString into a new text node
		DOMText *text = [[startNode ownerDocument] createTextNode:aTextString];
		
		// fire up a new anchor with text
		DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement *)[[startNode ownerDocument] createElement:@"a"];
		[anchor setHref:aURLAsString];
		[anchor appendChild:text];
		
		// split the DOM at aPosition
		DOMNode *split = [(DOMText *)startNode splitText:aPosition];
		
		// add the new anchor before the split
		[[DOMNode class] node:[startNode parentNode] insertBefore:anchor :split];
	}
	else
	{
		NSBeep();
		LOG((@"insertText:href:inRange:atPosition: DOMRange does not respond to splitText:!"));
	}
}

#pragma mark -
#pragma mark WebResourceLoadDeleate Methods


-(NSURLRequest *)webView:(WebView *)sender
				resource:(id)identifier
		 willSendRequest:(NSURLRequest *)request
		redirectResponse:(NSURLResponse *)redirectResponse
		  fromDataSource:(WebDataSource *)dataSource
{
	NSURL *requestURL = [request URL];
	//	LOG((@"REQUEST URL:%@", requestURL));
	if ( nil != requestURL )
	{
		NSString *relativePath = [requestURL relativePath];
		if ( [relativePath hasPrefix:[NSString stringWithFormat:@"/%@", kKTMediaPath]] )
		{
			switch ([[self document] publishingMode])
			{
				case kGeneratingPreview:
				{
					NSMutableString *substituted = [NSMutableString stringWithString:[requestURL absoluteString]];
					[substituted replaceOccurrencesOfString:@"applewebdata://" 
												 withString:[NSString stringWithFormat:@"media:/%@/", [[self document] documentID]]
													options:NSLiteralSearch 
													  range:NSMakeRange(0,[substituted length])];
					//NSLog(@"intercepted URL: %@", [requestURL absoluteString]);
					NSURL *substituteURL = [NSURL URLWithString:substituted];
					//NSLog(@"substituting URL: %@", [substituteURL absoluteString]);
					return [NSURLRequest requestWithURL:substituteURL];
				}
				default:
					break;
			}
		}
	}
	
	// if not a Media URL and not kGeneratingPreview,
	// just return the original request
	return request;
}


#pragma mark -
#pragma mark Notification Handlers

- (void)designChangedNeedWebViewUpdate:(NSNotification *)aNotification
{
	if ( (nil != [aNotification userInfo]) && (YES == [[[aNotification userInfo] valueForKey:@"animate"] boolValue]) )
	{
		myAnimateStartingPoint = NSPointFromString([[aNotification userInfo] valueForKey:@"mouse"]);
		
		if ([self webViewIsEditing])
		{
			// Act as if we ended editing, so changes get saved
			(void) [self webView:oWebView shouldEndEditingInDOMRange:nil];	// manually call this to force some stuff that's skipped if we end this way
			
			// DON'T suspend
			[self setSuspendNextWebViewUpdate:DONT_SUSPEND];
		}

		
		[self updateWebViewAnimated];
	}
}

/*!	Called when we get kKTWebViewMayNeedRefreshingNotification, e.g. after a change in an preference that can affect display
*/
- (void)webviewMayNeedRefreshing:(NSNotification *)aNotification
{
	if ((nil != [aNotification object]) && ([aNotification object] != [self document]))
	{
		return;
	}
	//	LOG((@"%@ ... suspend = %d", NSStringFromSelector(_cmd), [self suspendNextWebViewUpdate] ));
	
	if (DONT_SUSPEND == [self suspendNextWebViewUpdate])
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(delayedRefreshWebView:) object:nil];
		[self performSelector:@selector(delayedRefreshWebView:) withObject:nil afterDelay:0.0];	
	}
	else if (SUSPEND_ONCE == [self suspendNextWebViewUpdate])	// if set to 1, then automatically turn off
	{
		[self setSuspendNextWebViewUpdate:DONT_SUSPEND];	// Don't refresh; now done with suspending
	}
	// otherwise, you need to turn it off
}

/*!	Actually handle the request to refresh.	 Called after a delayed perform selector.
*/

- (void)delayedRefreshWebView:(id)bogus
{
//	LOG((@"%@", NSStringFromSelector(_cmd)));
	[self setSuspendNextWebViewUpdate:SUSPEND_ONCE];
	[self updateWebView];	// OK, ready to finally do it
	[self setSuspendNextWebViewUpdate:DONT_SUSPEND];
}




@end

