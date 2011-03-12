/* =============================================================================

	Partly based on code by ...

	AUTHORS:	M. Uli Kusterer <witness@zathras.de>, (c) 2003, all rights
				reserved.
	
	REVISIONS:
		2003-05-31	UK	Created.
   ========================================================================== */

#import "KTHTMLEditorController.h"

#import "DOMNode+KTExtensions.h"
#import "Debug.h"
#import "KTApplication.h"
#import "KTDocWindowController.h"
#import "KTPage.h"
#import "KSAppDelegate.h"
#import "NSString+Karelia.h"
#import "KSSHA1Stream.h"
#import "NSImage+Karelia.h"
#import "NSTextView+KTExtensions.h"
#import "SVValidatorWindowController.h"
#import "SVRawHTMLGraphic.h"
#import "Registration.h"


@implementation KTHTMLEditorWindow

- (BOOL) canBecomeMainWindow
{
	return NO;
}
@end

@interface KTHTMLEditorController ()

- (BOOL)isHTML;
- (void)calculateCachedPreludes;
- (void) autoValidate;
- (NSData *)generateHashFromFragment:(NSString *)fragment;
- (void)loadFragment:(NSString *)fragmentString;
@property (nonatomic, retain) SVOffscreenWebViewController *asyncOffscreenWebViewController;

-(IBAction)	recolorCompleteFile: (id)sender;
-(IBAction) recolorCompleteFileDeferred: (id)sender;
-(void)		recolorRange: (NSRange)range;

- (void)saveBackToSource:(NSNumber *)disableUndoRegistration;
@end

@implementation KTHTMLEditorController

@synthesize undoManager = _undoManager;
@synthesize autoSyntaxColoring = _autoSyntaxColoring;
@synthesize maintainIndentation = _maintainIndentation;
@synthesize recolorTimer = _recolorTimer;
@synthesize syntaxColoringBusy = _syntaxColoringBusy;
@synthesize affectedCharRange = _affectedCharRange;
@synthesize replacementString = _replacementString;
@synthesize title = _title;
@synthesize contentType = _contentType;
@synthesize cachedLocalPrelude = _cachedLocalPrelude;
@synthesize cachedRemotePrelude = _cachedRemotePrelude;
@synthesize validationState = _validationState;
@synthesize shouldPreviewWhenEditing = _shouldPreviewWhenEditing;
@synthesize hashOfLastValidation = _hashOfLastValidation;
@synthesize hasRemoteLoads = _hasRemoteLoads;


/* -----------------------------------------------------------------------------
	init:
		Constructor that inits _sourceCode member variable as a flag. It's
		storage for the text until the NIB's been loaded.
   -------------------------------------------------------------------------- */

-(id)	init
{
    self = [super initWithWindowNibName:@"HTMLEditor"];
    if (self)
	{
		_sourceCodeTemp = nil;
		_autoSyntaxColoring = YES;
		_maintainIndentation = YES;
		_recolorTimer = nil;
		_syntaxColoringBusy = NO;
	}
    return self;
}

- (id)initWithWindow:(NSWindow *)window;		// designated initializer
{
	if ((self = [super initWithWindow:window]) != nil)
	{
		// Put this in designated initializer so that when dealloc happens we are guaranteed observation was happening
		[self addObserver:self forKeyPath:@"contentType" options:0 context:@"synchronizeUIContext"];
		[self addObserver:self forKeyPath:@"shouldPreviewWhenEditing" options:0 context:@"synchronizeUIContext"];
	}
	return self;
}

- (NSArray *)contentTypeTagArray
{
	static NSArray *sContentTypeTagArray = nil;
	if (!sContentTypeTagArray)
	{
		sContentTypeTagArray = [[NSArray alloc] initWithObjects:
								(NSString *)kUTTypeHTML,				// yes preview
								(NSString *)kUTTypeHTML,				// no preview
								@"public.php-script",
								@"com.netscape.javascript-source",
								(NSString *)kUTTypeText,
								nil];
	}
	return sContentTypeTagArray;
}

- (ContentTypeTag) tagConformingToType:(NSString *)aType
{
	int whichTag = NSNotFound;
	int i = 0;
	for (NSString *type in self.contentTypeTagArray)
	{
		if ([aType conformsToUTI:type])
		{
			whichTag = i;
			break;
		}
		else
		{
			i++;
		
		}
		if (NSNotFound == whichTag)
		{
			whichTag = kTagContentOther;
		}
	}
	return whichTag;
}

- (void)synchronizeUI
{
	if (contentTypePopUp)
	{
		
		NSInteger whichTag = [self tagConformingToType:self.contentType];
		if ([self.contentType isEqualToString:(NSString *)kUTTypeHTML] && !self.shouldPreviewWhenEditing)
		{
			whichTag = kTagContentHTMLNoPreview;
		}
		NSMenuItem *contentTypeMenuItem = [[contentTypePopUp menu] itemWithTag:whichTag];
		if (contentTypeMenuItem)		// don't bother if we haven't loaded nib yet
		{
			[contentTypePopUp selectItem:contentTypeMenuItem];	// Check initially chosen one.
			
			[self calculateCachedPreludes];
			[self autoValidate];
			
			NSString *windowTitle = nil;
			if (nil == _title || [_title isEqualToString:@""])
			{
				windowTitle = NSLocalizedString(@"Edit HTML", @"Window title");
			}
			else
			{
				windowTitle =[NSString stringWithFormat:NSLocalizedString(@"Edit \\U201C%@\\U201D HTML", @"Window title, showing title of element"), _title];
			}
			[[self window] setTitle:windowTitle];
		}
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([((NSString *)context) isEqualToString:@"synchronizeUIContext"])
	{
		[self synchronizeUI];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

-(void)	dealloc
{
	[self removeObserver:self forKeyPath:@"contentType"];
	[self removeObserver:self forKeyPath:@"shouldPreviewWhenEditing"];

	[[self asyncOffscreenWebViewController] stopLoading];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	[_recolorTimer invalidate];
	[_recolorTimer release];
	
    self.undoManager = nil;
    self.recolorTimer = nil;
    self.replacementString = nil;
    self.HTMLSourceObject = nil;
    self.sourceCodeTemp = nil;
    self.title = nil;
    self.asyncOffscreenWebViewController = nil;
    self.cachedLocalPrelude = nil;
    self.cachedRemotePrelude = nil;
    self.hashOfLastValidation = nil;
	    
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
 
	// Kick start
	[self synchronizeUI];
	
	// HIG on positioning in Bottom Bar: http://j.mp/9BO0tS
	[[self window] setContentBorderThickness:22.0 forEdge:NSMinYEdge];	// have to do in code until 10.6

	// Load source code into text view, if necessary.  But then we no longer use this ivar
	if( _sourceCodeTemp != nil )
	{
		[textView setString: _sourceCodeTemp];
		[_sourceCodeTemp release];
		_sourceCodeTemp = nil;
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

- (void)windowDidBecomeKey:(NSNotification *)notification;
{
	if ([self HTMLSourceObject])
	{
		[NSTextView startRecordingFontChanges];
		[textView setUsesFontPanel:YES];
	}
	
}

// STUB -- I would like to make this work so I could set the font regardless of what is selected.  However this is not getting invoked. Any idea?
- (void)changeFont:(id)sender 
{
    return; 
}


- (void)windowWillClose:(NSNotification *)aNotification
{
	if ( [[aNotification object] isEqual:[self window]] )
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self];	// cancel pending update of status
		[self saveBackToSource:nil];
		
		[[self window] saveFrameUsingName:@"RawHTMLPanel"];
	}
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];		// cancel pending update of status
}

- (IBAction) windowHelp:(id)sender
{
	[[NSApp delegate] showHelpPage:@"Edit_Raw_HTML"];	// HELPSTRING
}

- (IBAction) applyChanges:(id)sender;
{
	[self saveBackToSource:nil];
	
	// Also I want to test the loading
	[self loadFragment:[[textView textStorage] string]];
}

- (IBAction)  contentTypePopupChanged:(id)sender;
{
	NSMenuItem *selectedItem = [sender selectedItem];		// which item just got selected

	int tag = [selectedItem tag];
	if (tag < [self.contentTypeTagArray count])
	{
		self.contentType = [self.contentTypeTagArray objectAtIndex:tag];
	}
	self.shouldPreviewWhenEditing = (kTagContentHTML == tag);
}

- (void)calculateCachedPreludes;
{
	
}

- (void) autoValidate;	// check validity while the user is typing
{
	if (![self isHTML])
	{
		self.validationState = kValidationStateDisabled;
		return;
	}

	// Use NSXMLDocument -- not useful for errors, but it's quick.
	NSMutableAttributedString*  textStore = [textView textStorage];
	NSString *html = [textStore string];
	NSData *currentHash = [self generateHashFromFragment:html];
	
	if (!currentHash)
	{
		self.validationState = kValidationStateUnknown;
	}
	else if ([self.hashOfLastValidation isEqual:currentHash])
	{
		self.validationState = kValidationStateVerifiedGood;
		// Text has changed insignificantly (e.g. just white space changes,
		// or perhaps text has changed *back* to how it was when it was validated as good,
		// set our validation state to be good.  Only if text has changed will we go back to the "maybe"/"bad" state.
	}
	else
	{
        if ([[self HTMLSourceObject] shouldValidateAsFragment])
        {
            html = [SVHTMLValidator HTMLStringWithFragment:html docType:KSHTMLWriterDocTypeHTML_5];
        }
        
        NSError *error = nil;
		self.validationState = [SVHTMLValidator validateHTMLString:html docType:KSHTMLWriterDocTypeHTML_5 error:&error];
        
        
        // Going by the docs, NSXMLDocument doesn't follow usual error handling rules. Instead it can use err to indicate warnings etc. even when parsing succeeded
        if (error)	// This might a warning or diagnosis for HTML 4.01
        {
            NSLog(@"validation Error: %@", [error localizedDescription]);
        }
	}
}

// Calculate hash of the string, but ignore multiple whitespace runs, so that edits that just change whitespace won't lose any "good" validation state
- (NSData *)generateHashFromFragment:(NSString *)fragment;
{
	NSData *digest = nil;
	NSString *stringToHash = [fragment condenseWhiteSpace];
	if (![stringToHash isEqualToString:@""])
	{
		NSData *dataToHash = [stringToHash dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
		digest = [dataToHash SHA1Digest];
//		NSLog(@"Hash of '%@' %@ is: %@", stringToHash, dataToHash, digest);
	}
	return digest;		// will be nil if the string is empty or white space only.
}

- (BOOL)isHTML
{
	BOOL conforms = [self.contentType conformsToUTI:(NSString *)kUTTypeHTML];
	return conforms;
}

- (BOOL) canValidate;
{
	BOOL validationStateOK = self.validationState > kValidationStateDisabled;
	BOOL conforms = [self.contentType conformsToUTI:(NSString *)kUTTypeHTML];
	BOOL result = validationStateOK && conforms;
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingCanValidate;
{
    return [NSSet setWithObjects:@"validationState", @"contentType", @"shouldPreviewWhenEditing", nil];
}

- (IBAction) validate:(id)sender;
{
	NSMutableAttributedString*  textStore = [textView textStorage];
	NSString *fragment = [textStore string];

	NSString *html = fragment;
    if ([[self HTMLSourceObject] shouldValidateAsFragment])
    {
        html = [SVRemoteHTMLValidator HTMLStringWithFragment:fragment docType:KSHTMLWriterDocTypeHTML_5];
    }
	
	NSString *docTypeName = [SVHTMLContext nameOfDocType:KSHTMLWriterDocTypeHTML_5 localize:NO];
	BOOL isValid = [[SVValidatorWindowController sharedController]
					validateSource:html
					pageValidationType:([[self HTMLSourceObject] shouldValidateAsFragment] ? kSandvoxFragment : kNonSandvoxHTMLPage)
					disabledPreviewObjectsCount:0
					charset:@"UTF-8"
					docTypeString:docTypeName
					windowForSheet:[self window]];	// it will do loading, displaying, etc.
		
	if (isValid)
	{
		self.validationState = kValidationStateVerifiedGood;
		self.hashOfLastValidation = [self generateHashFromFragment:fragment];
	}
	else
	{
		// Don't change status; it will stay as-is OK.  However, remove the hash since our validation 
		self.hashOfLastValidation = nil;
	}
}

- (void)saveBackToSource:(NSNumber *)disableUndoRegistration
{
	if ([self HTMLSourceObject])
	{
        // Disable undo registration if requested
        NSManagedObjectContext *MOC = nil;
        if (disableUndoRegistration && [[self HTMLSourceObject] isKindOfClass:[NSManagedObject class]])
        {
            MOC = [(NSManagedObject *)[self HTMLSourceObject] managedObjectContext];
            [MOC processPendingChanges];
            [[MOC undoManager] disableUndoRegistration];
        }
        
        // Store the HTML etc.
		[self HTMLSourceObject].contentType = self.contentType;
		[self HTMLSourceObject].HTMLString = [[textView textStorage] string];
		[self HTMLSourceObject].lastValidMarkupDigest = self.hashOfLastValidation;
		[self HTMLSourceObject].shouldPreviewWhenEditing = [NSNumber numberWithBool:self.shouldPreviewWhenEditing];
		
        // Re-enable undo registration
        if (MOC)
        {
            [MOC processPendingChanges];
            [[MOC undoManager] enableUndoRegistration];
        }
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
	if( _autoSyntaxColoring && range.length > 0 )
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
	
	// Validate markup, after a delay
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self performSelector:@selector(autoValidate) withObject:nil afterDelay:0.5];		// one second delay to auto-save-back
}


-(void)	didChangeText	// This actually does what we want to do in textView:shouldChangeTextInRange:
{
	if( _maintainIndentation && _replacementString && ([_replacementString isEqualToString:@"\n"]
													 || [_replacementString isEqualToString:@"\r"]) )
	{
		NSMutableAttributedString*  textStore = [textView textStorage];
		BOOL						hadSpaces = NO;
		unsigned int				lastSpace = _affectedCharRange.location,
		prevLineBreak = 0;
		NSRange						spacesRange = { 0, 0 };
		unichar						theChar = 0;
		unsigned int				x = (_affectedCharRange.location == 0) ? 0 : _affectedCharRange.location -1;
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
	if( _maintainIndentation )
	{
		_affectedCharRange = afcr;
		if( _replacementString )
		{
			[_replacementString release];
			_replacementString = nil;
		}
		_replacementString = [rps retain];
		
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
    if (!_undoManager) _undoManager = [[NSUndoManager alloc] init];
    return _undoManager;
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
	[_recolorTimer invalidate];
	[_recolorTimer release];
	
	// Schedule a new timer:
	_recolorTimer = [[NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(recolorSyntaxTimer:)
		userInfo:nil repeats: NO] retain];
}

// This actually triggers the recoloring:
-(void)	recolorSyntaxTimer: (NSTimer*) sender
{
	[_recolorTimer release];
	_recolorTimer = nil;
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
	if( _sourceCodeTemp != nil && textView )
	{
		[textView setString: _sourceCodeTemp]; // Causes recoloring notification.
		[_sourceCodeTemp release];
		_sourceCodeTemp = nil;
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
	if( _syntaxColoringBusy )	// Prevent endless loop when recoloring's replacement of text causes processEditing to fire again.
		return;
	
	if( textView == nil || range.length == 0	// Don't like doing useless stuff.
		|| _recolorTimer )						// And don't like recoloring partially if a full recolorization is pending.
		return;

	{
		NS_DURING
			_syntaxColoringBusy = YES;
			[progress startAnimation:nil];
			
			[status setStringValue: [NSString stringWithFormat: @"Recoloring syntax in %@", NSStringFromRange(range)]];
			
			[textView recolorRange:range];
			
			[progress stopAnimation:nil];
			_syntaxColoringBusy = NO;
		NS_HANDLER
			_syntaxColoringBusy = NO;
			[progress stopAnimation:nil];
			[localException raise];
		NS_ENDHANDLER
	}	
}

#pragma mark Accessors

@synthesize sourceCodeTemp = _sourceCodeTemp;
- (void)setSourceCodeTemp:(NSString *)aSourceCode
{
	[_sourceCodeTemp release];
	_sourceCodeTemp = [aSourceCode copy];
	
	/* Try to load it into textView and syntax colorize it:
		Since this may be called before the NIB has been loaded, we keep around
		_sourceCode as a data member and try these two calls again in windowControllerDidLoadNib: */
	if (nil != _sourceCodeTemp)
	{
		[self recolorCompleteFile:nil];
	}
	
	
}

@synthesize HTMLSourceObject = _HTMLSourceObject;
- (void) setHTMLSourceObject:(id <KTHTMLSourceObject>)graphic;
{
	[_HTMLSourceObject release];
	_HTMLSourceObject = [graphic retain];
	
	// load additional properties from the source object
	
	self.sourceCodeTemp = graphic.HTMLString;
	
	NSString *contentType = graphic.contentType;
	if (!contentType) contentType = (NSString *)kUTTypeHTML;
	self.contentType = contentType;
	
	NSNumber *shouldPreviewValue = graphic.shouldPreviewWhenEditing;
	if (shouldPreviewValue) 
	{
		self.shouldPreviewWhenEditing = [shouldPreviewValue boolValue];
	}
	else
	{
		self.shouldPreviewWhenEditing = YES;		// If unknown in source object, use a nice default value
	}
	self.hashOfLastValidation = graphic.lastValidMarkupDigest;
	
	[self loadFragment:graphic.HTMLString];
}

@synthesize completionSelector = _completionSelector;

#pragma mark Other

+ (NSSet *)keyPathsForValuesAffectingValidationIcon;
{
    return [NSSet setWithObject:@"validationState"];
}
+ (NSSet *)keyPathsForValuesAffectingValidationInfo;
{
    return [NSSet setWithObject:@"validationState"];
}

- (NSImage *)validationIcon
{
	NSImage *result = nil;
	switch(self.validationState)
	{
		case kValidationStateUnknown:	result = nil; break;
		case kValidationStateUnparseable:
		case kValidationStateValidationError:	result = [NSImage imageNamed:@"caution"]; break;	// like 10.6 NSCaution but better for small sizes
		case kValidationStateDisabled:
		case kValidationStateLocallyValid:		result = [NSImage imageFromOSType:kAlertNoteIcon]; break;
		case kValidationStateVerifiedGood:		result = [NSImage imageNamed:@"checkmark"]; break;
	}
	return result;
}

- (NSString *)validationInfo
{
	NSString *result = nil;
	switch(self.validationState)
	{
		case kValidationStateUnknown:	result = nil; break;
		case kValidationStateUnparseable:		result = NSLocalizedString(@"Problems detected with this HTML. Validate for more information.", @"status of HTML text entered into window"); break;
			
			// Parseable, but DTD validation error.  Give user just a bit more hint about what might be wrong.
		case kValidationStateValidationError:	result = NSLocalizedString(@"Problems detected with the structure of the HTML. Validate for more information.", @"status of HTML text entered into window"); break;
		case kValidationStateLocallyValid:		result = NSLocalizedString(@"HTML appears OK. Validate for detailed diagnostics.", @"status of HTML text entered into window"); break;
		case kValidationStateVerifiedGood:		result = NSLocalizedString(@"This HTML is confirmed as being valid.", @"status of HTML text entered into window"); break;
		case kValidationStateDisabled:			result = NSLocalizedString(@"Validation is disabled for this type of content", @"status of HTML text entered into window"); break;

	}
	return result;
}

#pragma mark -
#pragma mark Offscreen loader

- (void)loadFragment:(NSString *)fragmentString;
{
	[[self asyncOffscreenWebViewController] setDelegate:self];
	// NOT USED? [self setElementWaitingForFragmentLoad:element];
	// Kick off load of fragment, we will be notified when it's done.
	SVOffscreenWebViewController *asyncLoader = [self asyncOffscreenWebViewController];
	WebView *webview = [asyncLoader webView];
	[webview setResourceLoadDelegate:self];
	
	self.hasRemoteLoads = NO;	// this will get turned on if a request for a remote load comes in
	
	[asyncLoader  loadHTMLFragment:fragmentString];
	
}

#pragma mark -
#pragma mark Web Resource Load Delegate
// Resource load delegate -- so I can know that we are trying to load off-page resources

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource;
{
	NSURLRequest *result = request;
	//NSLog(@"%s %@ %@",__FUNCTION__, identifier, request);
	
	NSURL *URL = [request URL];
	NSString *scheme =[URL scheme];
	if (![scheme isEqualToString:@"about"])
	{
		self.hasRemoteLoads = YES;
		result = nil;				// deny this -- cancel loading this request
        
        // You'd think stopping the load (via WebView or WebFrame) is prudent since we're no longer loading. However, it seems that doing so from inside this delegate method will generally cause the WebView to crash. If we deny loading of all of resources, loading will be over almost straightaway though, so it's nearly the same. #101223
        
		LOG((@"found resource; stopping %@", sender));
	}
	return result;
}



#pragma mark -

/*	This splices the DOM tree that has been loaded into the offscreen webview into the element
 *	that is waiting for this fragment to have finished loading, [self elementWaitingForFragmentLoad].
 *	First it removes any existing children of that element (since we are replacing it),
 *	Then it imports the loaded body into the destination webview's DOMDocument (via importNode::)
 *	Finally, it loops through each element and find all the <script> elements, and, in order to
 *	prevent any script tags from executing (again, since they would have executed in the offscreen
 *	view), it strips out the info that will allow the script to execute.  This unfortunately affects
 *	the DOM for view source, but this isn't stored in the permanent database since this is just
 *	surgery on the currently viewed webview.
 * 
 *	Finally, after processing, we insert the new tree into the webview's tree, and process editing
 *	nodes to bring us the green + markers.
 */
- (void)offscreenWebViewController:(SVOffscreenWebViewController *)controller
                       didLoadBody:(DOMHTMLElement *)loadedBody;
{
	// Do nothing ... we will have gotten hasRemoteLoads set if there were any resources loaded
}

@synthesize asyncOffscreenWebViewController = _asyncOffscreenWebViewController;
- (SVOffscreenWebViewController *)asyncOffscreenWebViewController
{
	if (!_asyncOffscreenWebViewController)
	{
		_asyncOffscreenWebViewController = [[SVOffscreenWebViewController alloc] init];
	}
    return _asyncOffscreenWebViewController; 
}

@end
