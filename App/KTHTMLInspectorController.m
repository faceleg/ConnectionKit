/* =============================================================================

	Partly based on code by ...

	AUTHORS:	M. Uli Kusterer <witness@zathras.de>, (c) 2003, all rights
				reserved.
	
	REVISIONS:
		2003-05-31	UK	Created.
   ========================================================================== */

#import "KTHTMLInspectorController.h"

#import "DOMNode+KTExtensions.h"
#import "Debug.h"
#import "KTApplication.h"
#import "KTDocWindowController.h"
#import "KTPage.h"
#import "KSAppDelegate.h"
#import "NSString+Karelia.h"
#import "NSTextView+KTExtensions.h"

#import "Registration.h"

@interface KTHTMLInspectorController ( Private )


-(NSDictionary*)	defaultTextAttributes;		// Style attributes dictionary for an NSAttributedString.
-(NSString*)		syntaxDefinitionFilename;   // Defaults to "SyntaxDefinition.plist" in the app bundle's "Resources" directory.
-(NSDictionary*)	syntaxDefinitionDictionary; // Defaults to loading from -syntaxDefinitionFilename.
-(IBAction)	recolorCompleteFile: (id)sender;
-(IBAction) recolorCompleteFileDeferred: (id)sender;
-(void)		recolorRange: (NSRange)range;

- (void)saveBackToSource:(NSNumber *)disableUndoRegistration;
@end

@implementation KTHTMLInspectorController


/* -----------------------------------------------------------------------------
	init:
		Constructor that inits mySourceCode member variable as a flag. It's
		storage for the text until the NIB's been loaded.
   -------------------------------------------------------------------------- */

-(id)	init
{
	if ( !(gIsPro || (nil == gRegistrationString)  ) )	// don't allow this to be created if we're not pro
	{
		NSBeep();
		[self release];
		return nil;
	}
    self = [super initWithWindowNibName:@"HTMLEditor"];
    if (self)
	{
		mySourceCode = nil;
		autoSyntaxColoring = YES;
		maintainIndentation = YES;
		recolorTimer = nil;
		syntaxColoringBusy = NO;
	}
    return self;
}


-(void)	dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[recolorTimer invalidate];
	[recolorTimer release];
	recolorTimer = nil;
	[replacementString release];
	replacementString = nil;
    [self setHTMLSourceObject:nil];
    [self setHTMLSourceKeyPath:nil];
	[self setTitle:nil];
	[self setSourceCode:nil];
	[self setExplanation:nil];
    [myUndoManager release];
    
	[super dealloc];
}

/* -----------------------------------------------------------------------------
windowDidLoad
NIB has been loaded, fill the text view with our text and apply
initial syntax coloring.
-------------------------------------------------------------------------- */

- (void)windowDidLoad
{
    [super windowDidLoad];
    
	// Load source code into text view, if necessary:
	if( mySourceCode != nil )
	{
		[textView setString: mySourceCode];
		[mySourceCode release];
		mySourceCode = nil;
	}
	
	// Set up our progress indicator:
	[progress setStyle: NSProgressIndicatorSpinningStyle];	// NIB forgets that :-(
	[progress setDisplayedWhenStopped:NO];
	[progress setUsesThreadedAnimation:YES];
	
	[textView setTextContainerInset:NSMakeSize(3.0,5.0)];
	[textView setAllowsUndo:YES];
	[status setStringValue: @"Finished."];
	
	// Register for "text changed" notifications of our text storage:
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processEditing:)
												 name: NSTextStorageDidProcessEditingNotification
											   object: [textView textStorage]];
	
	// Put selection at top like Project Builder has it, so user sees it:
	[textView setSelectedRange: NSMakeRange(0,0)];
	
	// Make sure text isn't wrapped:
//	[textView turnOffWrapping];
	
	// Do initial syntax coloring of our file:
	[self recolorCompleteFile:nil];
	
	// Make sure we can use "find" if we're on 10.3:
	if( [textView respondsToSelector: @selector(setUsesFindPanel:)] )
		[textView setUsesFindPanel: YES];
	
	[[self window] setFrameAutosaveName:@"RawHTMLPanel"];
	[[self window] setFrameUsingName:@"RawHTMLPanel"];
}


- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	NSString *result = nil;
	if (nil == myTitle || [myTitle isEqualToString:@""])
	{
		result =[displayName stringByAppendingFormat:@" %C HTML", 0x2014];
	}
	else
	{
		result =[displayName stringByAppendingFormat:@" %C %@ %C HTML", 0x2014, myTitle, 0x2014];
	}
	return result;
}

//
//	// Try to get selection info if possible:
//	NSAppleEventDescriptor*  evt = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
//	if( evt )
//	{
//		NSAppleEventDescriptor*  param = [evt paramDescriptorForKeyword: keyAEPosition];
//		if( param )		// This is always false when xCode calls us???
//		{
//			NSData*					data = [param data];
//			struct SelectionRange   range;
//			
//			memmove( &range, [data bytes], sizeof(range) );
//			
//			if( range.lineNum >= 0 )
//				[self goToLine: range.lineNum +1];
//			else
//				[self goToRangeFrom: range.startRange toChar: range.endRange];
//		}
//	}

#pragma mark -
#pragma mark Window Notifications

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	if ([[aNotification object] isEqual:[self window]])
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
		[self saveBackToSource:nil];
        
        [[textView undoManager] removeAllActions];
	}
}

- (void)windowDidBecomeKey:(NSNotification *)notification;
{
	if (myHTMLSourceObject)
	{
		NSTimeInterval timeSinceLastChange = [NSDate timeIntervalSinceReferenceDate] - myLastEditTime;
		if (timeSinceLastChange > 1.5)	// last change must have been MORE than 1.5 seconds AGO in order to re-load from the window.
		{
			// reload from model
			NSString *source = [myHTMLSourceObject valueForKeyPath:myHTMLSourceKeyPath];
//			DJW((@"load source from %@ = %@", myHTMLSourceKeyPath, source));
			if (nil == source) source = @"";
			source = [source stringByReplacing:[NSString stringWithUnichar:160] with:@"&nbsp;"];
			source = [source trim];

			while (NSNotFound != [source rangeOfString:@"\n\n\n"].location)
			{
				source = [source stringByReplacing:@"\n\n\n" with:@"\n\n"];	// Try to trim down the text so we don't have bug where extra blank lines are added
			}
			[self setSourceCode:source];
			[NSTextView startRecordingFontChanges];
		}
	}

}


- (void)windowWillClose:(NSNotification *)aNotification
{
	if ( [[aNotification object] isEqual:[self window]] )
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
		[self saveBackToSource:nil];
		
		[[self window] saveFrameUsingName:@"RawHTMLPanel"];
	}
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self saveBackToSource:nil];
}

- (IBAction) windowHelp:(id)sender
{
	[[NSApp delegate] showHelpPage:@"Edit_Raw_HTML"];	// HELPSTRING
}


- (void)saveBackToSource:(NSNumber *)disableUndoRegistration
{
	if (myHTMLSourceObject)
	{
		myLastEditTime = [NSDate timeIntervalSinceReferenceDate] - 31556926;	// mark edit as being in the PAST so re-activate works no matter what now

		NSMutableAttributedString*  textStore = [textView textStorage];
        NSString *str = [[[textStore string] copy] autorelease];
        
		while (NSNotFound != [str rangeOfString:@"\n\n\n"].location)
		{
			str = [str stringByReplacing:@"\n\n\n" with:@"\n\n"];	// Try to trim down the text so we don't have bug where extra blank lines are added
		}

		
        
        // Disable undo registration if requested
        NSManagedObjectContext *MOC = nil;
        if (disableUndoRegistration && [myHTMLSourceObject isKindOfClass:[NSManagedObject class]])
        {
            MOC = [(NSManagedObject *)myHTMLSourceObject managedObjectContext];
            [MOC processPendingChanges];
            [[MOC undoManager] disableUndoRegistration];
        }
        
        // Store the HTML
        [myHTMLSourceObject setValue:str forKeyPath:myHTMLSourceKeyPath];
//		DJW((@"saved source to %@ = %@", myHTMLSourceKeyPath, str));

		
        // Re-enable undo registration
        if (MOC)
        {
            [MOC processPendingChanges];
            [[MOC undoManager] enableUndoRegistration];
        }
        
        
		// Now find the cdata tags and convert back to CDATA
		// myHTMLElement is a div or something, won't be changed, so no need to worry about myHTMLElement itself being replaced.
//		[myDOMHTMLElement replaceFakeCDataWithCDATA];
	}
	else
    {
        NSLog(@"Don't have any destination to save the HTML window");
    }
}

#pragma mark -
#pragma mark Editing

/* -----------------------------------------------------------------------------
	processEditing:
		Part of the text was changed. Recolor it.
		Responds to NSTextStorageDidProcessEditingNotification
   -------------------------------------------------------------------------- */


-(void) processEditing: (NSNotification*)notification
{
	myLastEditTime = [NSDate timeIntervalSinceReferenceDate];
	
    NSTextStorage	*textStorage = [notification object];
	NSRange			range = [textStorage editedRange];
	int				changeInLen = [textStorage changeInLength];
	BOOL			wasInUndoRedo = [[self undoManager] isUndoing] || [[self undoManager] isRedoing];
	BOOL			textLengthMayHaveChanged = NO;

	if (0 == range.location && NSMaxRange(range) == [textStorage length] && 0 != [textStorage length]) // only change if all selected
	{
		NSDictionary *newAttr = [textStorage attributesAtIndex:range.location effectiveRange:nil];
		[textView setDesiredAttributes:newAttr];
	}
	
	// Was delete op or undo that could have changed text length?
	if( wasInUndoRedo )
	{
		textLengthMayHaveChanged = YES;
		range = [textView selectedRange];
	}
	if( changeInLen <= 0 )
		textLengthMayHaveChanged = YES;
	
	//	Try to get chars around this to recolor any identifier we're in:
	if( textLengthMayHaveChanged )
	{
		if( range.location > 0 )
			range.location--;
		if( (range.location +range.length +2) < [textStorage length] )
			range.length += 2;
		else if( (range.location +range.length +1) < [textStorage length] )
			range.length += 1;
	}
	
	NSRange						currRange = range;
    
	// Perform the syntax coloring:
	if( autoSyntaxColoring && range.length > 0 )
	{
		NSRange			effectiveRange;
		NSString*		rangeMode;
		
		
		rangeMode = [textStorage attribute: TD_SYNTAX_COLORING_MODE_ATTR
								atIndex: currRange.location
								effectiveRange: &effectiveRange];
		
		unsigned int		x = range.location;
		
		/* TODO: If we're in a multi-line comment and we're typing a comment-end
			character, or we're in a string and we're typing a quote character,
			this should include the rest of the text up to the next comment/string
			end character in the recalc. */
		
		// Scan up to prev line break:
		while( x > 0 )
		{
			unichar theCh = [[textStorage string] characterAtIndex: x];
			if( theCh == '\n' || theCh == '\r' )
				break;
			--x;
		}
		
		currRange.location = x;
		
		// Scan up to next line break:
		x = range.location +range.length;
		
		while( x < [textStorage length] )
		{
			unichar theCh = [[textStorage string] characterAtIndex: x];
			if( theCh == '\n' || theCh == '\r' )
				break;
			++x;
		}
		
		currRange.length = x -currRange.location;
		
		// Open identifier, comment etc.? Make sure we include the whole range.
		if( rangeMode != nil )
			currRange = NSUnionRange( currRange, effectiveRange );
		
		// Actually recolor the changed part:
		[self recolorRange: currRange];
	}
	
	// Save this back to the source, after a delay
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self performSelector:@selector(saveBackToSource:) withObject:[NSNumber numberWithBool:YES] afterDelay:1.0];		// one second delay to auto-save-back
}


-(void)	didChangeText	// This actually does what we want to do in textView:shouldChangeTextInRange:
{
	NSLog(@"didChangeText");
	if( maintainIndentation && replacementString && ([replacementString isEqualToString:@"\n"]
													 || [replacementString isEqualToString:@"\r"]) )
	{
		NSMutableAttributedString*  textStore = [textView textStorage];
		BOOL						hadSpaces = NO;
		unsigned int				lastSpace = affectedCharRange.location,
		prevLineBreak = 0;
		NSRange						spacesRange = { 0, 0 };
		unichar						theChar = 0;
		unsigned int				x = (affectedCharRange.location == 0) ? 0 : affectedCharRange.location -1;
		NSString*					tsString = [textStore string];
		
		while( true )
		{
			if( x > ([tsString length] -1) )
				break;
			
			theChar = [tsString characterAtIndex: x];
			
			switch( theChar )
			{
				case '\n':
				case '\r':
					prevLineBreak = x +1;
					x = 0;  // Terminate the loop.
					break;
					
				case ' ':
				case '\t':
					if( !hadSpaces )
					{
						lastSpace = x;
						hadSpaces = YES;
					}
					break;
					
				default:
					hadSpaces = NO;
					break;
			}
			
			if( x == 0 )
				break;
			
			x--;
		}
		
		if( hadSpaces )
		{
			spacesRange.location = prevLineBreak;
			spacesRange.length = lastSpace -prevLineBreak +1;
			if( spacesRange.length > 0 )
				[textView insertText: [tsString substringWithRange:spacesRange]];
		}
	}
}


/* -----------------------------------------------------------------------------
	textView:shouldChangeTextinRange:replacementString:
		Perform indentation-maintaining if we're supposed to.
   -------------------------------------------------------------------------- */

- (BOOL)textView:(NSTextView *)tv shouldChangeTextInRange:(NSRange)afcr replacementString:(NSString *)rps
{
	if( maintainIndentation )
	{
		affectedCharRange = afcr;
		if( replacementString )
		{
			[replacementString release];
			replacementString = nil;
		}
		replacementString = [rps retain];
		
		// Took this out -- it never seemed to be actually invoked, and it would make us lose Japanese characters.
		//[self performSelector: @selector(didChangeText) withObject: nil afterDelay: 0.0];	// Queue this up on the event loop. If we change the text here, we only confuse the undo stack.
	}
	
	return YES;
}

#pragma mark -
#pragma mark Undo

/*  The text view needs its own undo manager separate from the documents
 */
- (NSUndoManager *)undoManagerForTextView:(NSTextView *)aTextView
{
    return [[self window] undoManager];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    if (!myUndoManager) myUndoManager = [[NSUndoManager alloc] init];
    return myUndoManager;
}

#pragma mark -
#pragma mark Deferring recoloring

/* -----------------------------------------------------------------------------
	recolorCompleteFileDeferred:
		Set a timer that waits a little and then re-colors the entire document.
		Since this is a slow action, by using a timer, if the user types some
		more, the recoloring will be "pushed back" until the user is finished
		typing. This may not look quite as good, but is a compromise between
		speed and accuracy we can sometimes take.
		
		This isn't actually used anywhere right now.
   -------------------------------------------------------------------------- */

-(IBAction) recolorCompleteFileDeferred: (id)sender
{
	// Drop any pending recalcs.
	[recolorTimer invalidate];
	[recolorTimer release];
	
	// Schedule a new timer:
	recolorTimer = [[NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(recolorSyntaxTimer:)
		userInfo:nil repeats: NO] retain];
}

// This actually triggers the recoloring:
-(void)	recolorSyntaxTimer: (NSTimer*) sender
{
	[recolorTimer release];
	recolorTimer = nil;
	[self recolorCompleteFile: self];	// Slow. During typing we only recolor the changed parts, but sometimes we need this instead.
}

#pragma mark -
#pragma mark Recoloring


/* -----------------------------------------------------------------------------
	recolorCompleteFile:
		IBAction to do a complete recolor of the whole friggin' document.
		This is called once after the document's been loaded and leaves some
		custom styles in the document which are used by recolorRange to properly
		perform recoloring of parts.
   -------------------------------------------------------------------------- */

-(IBAction)	recolorCompleteFile: (id)sender
{
	if( mySourceCode != nil && textView )
	{
		[textView setString: mySourceCode]; // Causes recoloring notification.
		[mySourceCode release];
		mySourceCode = nil;
	}
	else
	{
		NSRange		range = NSMakeRange(0,[[textView textStorage] length]);
		[self recolorRange: range];
	}
}


/* -----------------------------------------------------------------------------
	recolorRange:
		Try to apply syntax coloring to the text in our text view. This
		overwrites any styles the text may have had before. This function
		guarantees that it'll preserve the selection.
		
		Note that the order in which the different things are colorized is
		important. E.g. identifiers go first, followed by comments, since that
		way colors are removed from identifiers inside a comment and replaced
		with the comment color, etc. 
		
		The range passed in here is special, and may not include partial
		identifiers or the end of a comment. Make sure you include the entire
		multi-line comment etc. or it'll lose color.
		
		This calls oldRecolorRange to handle old-style syntax definitions.
   -------------------------------------------------------------------------- */

-(void)		recolorRange: (NSRange)range
{
	if( syntaxColoringBusy )	// Prevent endless loop when recoloring's replacement of text causes processEditing to fire again.
		return;
	
	if( textView == nil || range.length == 0	// Don't like doing useless stuff.
		|| recolorTimer )						// And don't like recoloring partially if a full recolorization is pending.
		return;

	{
		NS_DURING
			syntaxColoringBusy = YES;
			[progress startAnimation:nil];
			
			[status setStringValue: [NSString stringWithFormat: @"Recoloring syntax in %@", NSStringFromRange(range)]];
			
			[textView recolorRange:range];
			
			[progress stopAnimation:nil];
			syntaxColoringBusy = NO;
		NS_HANDLER
			syntaxColoringBusy = NO;
			[progress stopAnimation:nil];
			[localException raise];
		NS_ENDHANDLER
	}	
	

	
}

#pragma mark -
#pragma mark Accessors


- (BOOL)fromEditableBlock
{
    return fromEditableBlock;
}

- (void)setFromEditableBlock:(BOOL)flag
{
    fromEditableBlock = flag;
}



- (NSObject *)HTMLSourceObject
{
    return myHTMLSourceObject; 
}

- (void)setHTMLSourceObject:(NSObject *)anHTMLSourceObject
{
    [anHTMLSourceObject retain];
    [myHTMLSourceObject release];
    myHTMLSourceObject = anHTMLSourceObject;
}

- (NSString *)HTMLSourceKeyPath
{
    return myHTMLSourceKeyPath; 
}

- (void)setHTMLSourceKeyPath:(NSString *)anHTMLSourceKeyPath
{
    [anHTMLSourceKeyPath retain];
    [myHTMLSourceKeyPath release];
    myHTMLSourceKeyPath = anHTMLSourceKeyPath;
}


- (NSString *)sourceCode
{
    return mySourceCode; 
}

- (void)setSourceCode:(NSString *)aSourceCode
{
	[mySourceCode release];
	mySourceCode = [aSourceCode copy];
	
	/* Try to load it into textView and syntax colorize it:
		Since this may be called before the NIB has been loaded, we keep around
		mySourceCode as a data member and try these two calls again in windowControllerDidLoadNib: */
	if (nil != mySourceCode)
	{
		NSString *nsbpReplaced = [mySourceCode stringByReplacing:[NSString stringWithUnichar:160] with:@"&nbsp;"];
		[textView setString: nsbpReplaced];
		[self recolorCompleteFile:nil];
	}
	
	
	if (fromEditableBlock)
	{
		[self setExplanation:NSLocalizedString(@"This text can only contain HTML, no scripting constructs",@"")];
	}
	else
	{
		[self setExplanation:NSLocalizedString(@"This text can contain HTML or scripts such as JavaScript and PHP.",@"")];
	}
}


- (NSString *)title
{
    return myTitle; 
}

- (void)setTitle:(NSString *)aTitle
{
    [aTitle retain];
    [myTitle release];
    myTitle = aTitle;
}


- (NSString *)explanation
{
    return myExplanation; 
}
- (void)setExplanation:(NSString *)anExplanation
{
    [anExplanation retain];
    [myExplanation release];
    myExplanation = anExplanation;
}




@end
