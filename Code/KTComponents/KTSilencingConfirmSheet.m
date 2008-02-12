//
//  KTSilencingConfirmSheet.m
//  KTComponents
//
//  Created by Dan Wood on 7/29/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTSilencingConfirmSheet.h"

@interface NSTextView (SizeToFit)

- (NSSize)minSizeForContent;

@end

@implementation NSTextView (SizeToFit)

- (NSSize)minSizeForContent
{
	NSLayoutManager *layoutManager = [self layoutManager];
	NSTextContainer *textContainer = [self textContainer];
	
	[layoutManager boundingRectForGlyphRange:NSMakeRange(0, [layoutManager numberOfGlyphs]) inTextContainer:textContainer]; // dummy call to force layout
	NSRect usedRect = [layoutManager usedRectForTextContainer:textContainer];
	NSSize inset = [self textContainerInset];
	
	return NSInsetRect(usedRect, -inset.width * 2, -inset.height * 2).size;
}

@end



@interface KTSilencingConfirmSheet ( Private )

- (id)target;
- (void)setTarget:(id)aTarget;

- (NSString *)silencingDefaultsKey;
- (void)setSilencingDefaultsKey:(NSString *)aSilencingDefaultsKey;

- (NSWindow *)parentWindow;
- (void)setParentWindow:(NSWindow *)aParentWindow;

- (NSInvocation *)invocation;
- (void)setInvocation:(NSInvocation *)anInvocation;

+ (NSNib *)sharedNib;

@end

@implementation KTSilencingConfirmSheet

-(KTSilencingConfirmSheet *)initWithTarget:(id)aTarget
									window:(NSWindow *)aParentWindow
							  silencingKey:(NSString *)aSilencingKey
								 canCancel:(BOOL)aCanCancel
								  OKButton:(NSString *)anOKTitle	// can be nil to use standard OK
								   silence:(NSString *)aSilenceTitle
			// can be nil to use standard 'do not show again' (not recommended for cancelable operations)
									 title:(NSString *)aTitle
								   message:(id)aMessage
{
	NSParameterAssert(nil != aTarget);
	[super init];
	[self setTarget:aTarget];
	
	if (![[NSUserDefaults standardUserDefaults] boolForKey:aSilencingKey])
	{
		[self setParentWindow:aParentWindow];
		[self setSilencingDefaultsKey:aSilencingKey];
		
		BOOL instantiatedNib = [[KTSilencingConfirmSheet sharedNib]
			instantiateNibWithOwner:self
					topLevelObjects:nil];
		NSAssert(instantiatedNib, @"Nib not instantiated");

		// Fix the transparent background
		[oMessageTextView setDrawsBackground:NO];
		NSScrollView *scrollView = [oMessageTextView enclosingScrollView];
		[scrollView setDrawsBackground:NO];
		[[scrollView contentView] setCopiesOnScroll:NO];

		
		[oCancelButton setHidden:!aCanCancel];
		if (nil != anOKTitle)
		{
			[oOKButton setTitle:anOKTitle];
		}
		[oTitleText setStringValue:aTitle];
		[oMessageTextView setString:aMessage];

		if (nil != aSilenceTitle)
		{
			[oSilenceCheckbox setTitle:aSilenceTitle];
		}
				
		// Resize window to show as much of message as possible, but no less than 3 lines or more than, say, 50
		NSSize originalSize = [oMessageTextView frame].size;
		NSSize contentSize = [oMessageTextView minSizeForContent];
		if (contentSize.height > originalSize.height)
		{
			float delta = contentSize.height - originalSize.height;
			
#define DELTA 500.0
			if (delta > DELTA)
			{
				delta = DELTA;	// don't let get TOO tall; scrollbar will be there for us
			}
			NSSize oldContentSize = [[[oMessageTextView window] contentView] bounds].size;
			[[oMessageTextView window] setContentSize:NSMakeSize(oldContentSize.width, oldContentSize.height + delta)];
		}
	}
	return self;
}

- (IBAction)sheetOK: (id)sender
{
    [NSApp endSheet:oSheetWindow returnCode:NSOKButton];
}

- (IBAction)sheetCancel: (id)sender
{
    [NSApp endSheet:oSheetWindow returnCode:NSCancelButton];
}

- (void)windowWillClose:(NSNotification *)notification;
{
	[NSApp stopModal];
}

// Control is sent to the did-end selector, which cleans up by closing the custom sheet. It is important to call orderOut: when finished with your sheet, or it is not removed from the screen.

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:nil];
	
	if (NSOKButton == returnCode)
	{
		if ([oSilenceCheckbox state])	// Only heed the checkbox if you hit OK
		{
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:[self silencingDefaultsKey]];
		}
		if (nil != contextInfo)
		{
			[[self invocation] invokeWithTarget:[self target]];		// ONE PLACE FOR THE INVOCATION TO HAPPEN
		}
	}
	[self autorelease];		// balance retain when sheet began
}

-(void)dealloc
{
    [self setTarget:nil];
    [self setSilencingDefaultsKey:nil];
    [self setParentWindow:nil];
	[self setInvocation:nil];
    [super dealloc];
}

-(void)forwardInvocation:(NSInvocation *)anInvocation
{
	NSAssert(nil != [self target], @"need a target");
	[self setInvocation:anInvocation];

	if (nil != oSheetWindow)	// a non-nil window means we must verify first
	{
		if (nil != anInvocation)
		{
			[self retain];						// need to keep self around until sheet is dismissed
			[oSheetWindow setTitle:@""];
			[NSApp beginSheet: oSheetWindow
			   modalForWindow: [self parentWindow]
				modalDelegate: self
			   didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
				  contextInfo: anInvocation];	// use invocation for context
		}
		else
		{
			if (![[NSUserDefaults standardUserDefaults] boolForKey:[self silencingDefaultsKey]])
			{
				int returnCode = [NSApp runModalForWindow:oSheetWindow relativeToWindow:[self parentWindow]];
				
				if (NSOKButton == returnCode)
				{
					if ([oSilenceCheckbox state])	// Only heed the checkbox if you hit OK
					{
						[[NSUserDefaults standardUserDefaults] setBool:YES forKey:[self silencingDefaultsKey]];
					}
				}		
// FIXME: Figure out how to do a sheet that essentially blocks
				// DON'T USE, IT'S DEPRECATED (void) [NSApp runModalForWindow:oSheetWindow relativeToWindow:[self parentWindow]];
				[oSheetWindow orderOut:nil];
			}
		}
	}
	else if (nil != anInvocation)	// no confirm sheet; do the deed right away
	{
		/// Deal with problem where sheet would be autoreleased before invocation was run!
		[self retain];						// need to keep self around until deed is done
		[self performSelector:@selector(doTheInvocationAndRelease) withObject:nil afterDelay:0.0];
	}
}

- (void) doTheInvocationAndRelease	// do the invocation, then release this object.
{
	[[self invocation] invokeWithTarget:[self target]];
	[self autorelease];
}
	

/*!	Ask the target for its method signature
*/
-(NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	NSAssert(nil != [self target], @"need a target");

	NSMethodSignature *result = [super methodSignatureForSelector:aSelector];
	if (nil == result)
	{
		result = [[self target] methodSignatureForSelector:aSelector];
	}
	return result;
}

#pragma mark -
#pragma mark Accessors


- (id)target
{
    return myTarget; 
}

- (void)setTarget:(id)aTarget
{
    [aTarget retain];
    [myTarget release];
    myTarget = aTarget;
}

- (NSString *)silencingDefaultsKey
{
    return mySilencingDefaultsKey; 
}

- (void)setSilencingDefaultsKey:(NSString *)aSilencingDefaultsKey
{
    [aSilencingDefaultsKey retain];
    [mySilencingDefaultsKey release];
    mySilencingDefaultsKey = aSilencingDefaultsKey;
}

- (NSWindow *)parentWindow
{
    return myParentWindow; 
}

- (void)setParentWindow:(NSWindow *)aParentWindow
{
    [aParentWindow retain];
    [myParentWindow release];
    myParentWindow = aParentWindow;
}

- (NSInvocation *)invocation
{
    return myInvocation; 
}

- (void)setInvocation:(NSInvocation *)anInvocation
{
    [anInvocation retain];
    [myInvocation release];
    myInvocation = anInvocation;
}

+ (NSNib *)sharedNib
{
	static NSNib *sSilencingConfirmNib = nil;

	if (nil == sSilencingConfirmNib)
	{
		sSilencingConfirmNib = [[NSNib alloc] initWithNibNamed:@"SilencingWarningSheet"
														bundle:[NSBundle bundleForClass:[self class]]];
		NSAssert(sSilencingConfirmNib, @"nib could not be loaded");
	}
	return sSilencingConfirmNib;
}

+ (void) alertWithWindow:(NSWindow *)aWindow silencingKey:(NSString *)aSilencingKey title:(NSString *)aTitle format:(NSString *)format, ...
{
	va_list argList;
	va_start(argList, format);
	NSString *formatted = [[[NSString alloc] initWithFormat:format arguments:argList] autorelease];
	va_end(argList);
	
	KTSilencingConfirmSheet *sheet = [[[KTSilencingConfirmSheet alloc]
				initWithTarget:self
						window:aWindow
				  silencingKey:aSilencingKey
					 canCancel:NO
					  OKButton:nil
					   silence:nil
						 title:aTitle
					   message:formatted] autorelease];
	
	[sheet forwardInvocation:nil];	// kick off the alert, if needed

}

@end

@implementation NSObject ( KTSilencingConfirmSheet )

- (id)confirmWithWindow:(NSWindow *)aWindow silencingKey:(NSString *)aSilencingKey canCancel:(BOOL)aCanCancel OKButton:(NSString *)anOKTitle silence:(NSString *)aSilenceTitle title:(NSString *)aTitle format:(NSString *)format, ...
{
	va_list argList;
	va_start(argList, format);
	NSString *formatted = [[[NSString alloc] initWithFormat:format arguments:argList] autorelease];
	va_end(argList);
		
	return [[[KTSilencingConfirmSheet alloc]
				initWithTarget:self
						window:aWindow
				  silencingKey:aSilencingKey
					 canCancel:YES
					  OKButton:anOKTitle
						silence:aSilenceTitle
						 title:aTitle
					   message:formatted] autorelease];
}

@end
