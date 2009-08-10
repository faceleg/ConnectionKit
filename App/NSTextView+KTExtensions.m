//
//  NSTextView+KTExtensions.m
//  Marvel
//
//  Created by Dan Wood on 4/13/07.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

// Based on the guts of UKSyntaxColoredTextDocument by Uli K.


// Note: font from HTMLViewFontName & HTMLViewPointSize defaults


#import "NSTextView+KTExtensions.h"

#import "NSColor+Karelia.h"
#import "NSScanner+Karelia.h"

@interface NSTextView ( Private )

-(NSDictionary*)	syntaxDefinitionDictionary;
-(NSDictionary*)	defaultTextAttributes;


-(void) recolorRange: (NSRange) range;


-(void)	recolorSyntaxTimer: (NSTimer*) sender;

-(void)	colorOneLineComment: (NSString*) startCh inString: (NSMutableAttributedString*) s
				  withColor: (NSColor*) col andMode:(NSString*)attr;
-(void)	colorCommentsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
				withColor: (NSColor*) col andMode:(NSString*)attr;
-(void)	colorIdentifier: (NSString*) ident inString: (NSMutableAttributedString*) s
			  withColor: (NSColor*) col andMode:(NSString*)attr charset: (NSCharacterSet*)cset;
-(void)	colorStringsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
			   withColor: (NSColor*) col andMode:(NSString*)attr andEscapeChar: (NSString*)vStringEscapeCharacter;
-(void)	colorTagFrom: (NSString*) startCh to: (NSString*)endCh inString: (NSMutableAttributedString*) s
		   withColor: (NSColor*) col andMode:(NSString*)attr exceptIfMode: (NSString*)ignoreAttr;

@end

@implementation NSTextView ( KTExtensions )

// Class method is now a utility for other non-editable text views to use

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

-------------------------------------------------------------------------- */

-(void)		recolorRange: (NSRange)range
{
	if( range.length == 0	// Don't like doing useless stuff.
		)
		return;
	
	// Kludge fix for case where we sometimes exceed text length:ra
	int diff = [[self textStorage] length] -(range.location +range.length);
	if( diff < 0 )
		range.length += diff;
	
	NS_DURING
		
		// Get the text we'll be working with:
		NSMutableAttributedString*	vString = [[NSMutableAttributedString alloc] initWithString: [[[self textStorage] string] substringWithRange: range]];
		[vString autorelease];
		
		// Load colors and fonts to use from preferences:
		
		// Load our dictionary which contains info on coloring this language:
		NSDictionary*				vSyntaxDefinition = [self syntaxDefinitionDictionary];
		NSEnumerator*				vComponentsEnny = [[vSyntaxDefinition objectForKey: @"Components"] objectEnumerator];
		
		if( vComponentsEnny == nil )	// No new-style list of components to colorize? Use old code.
		{
			NS_VOIDRETURN;
		}
		
		// Loop over all available components:
		NSDictionary*				vCurrComponent = nil;
		NSDictionary*				vStyles = [self defaultTextAttributes];
		NSUserDefaults*				vPrefs = [NSUserDefaults standardUserDefaults];
		
		while( (vCurrComponent = [vComponentsEnny nextObject]) )
		{
			NSString*   vComponentType = [vCurrComponent objectForKey: @"Type"];
			NSString*   vComponentName = [vCurrComponent objectForKey: @"Name"];
			NSString*   vColorKeyName = [@"SyntaxColoring:Color:" stringByAppendingString: vComponentName];
			NSColor*	vColor = [NSColor colorWithArray:[vPrefs arrayForKey:vColorKeyName]];
			
			if( !vColor )
				vColor = [NSColor colorWithArray:[vCurrComponent objectForKey: @"Color"]];
			
			if( [vComponentType isEqualToString: @"BlockComment"] )
			{
				[self colorCommentsFrom: [vCurrComponent objectForKey: @"Start"]
									 to: [vCurrComponent objectForKey: @"End"] inString: vString
							  withColor: vColor andMode: vComponentName];
			}
			else if( [vComponentType isEqualToString: @"OneLineComment"] )
			{
				[self colorOneLineComment: [vCurrComponent objectForKey: @"Start"]
								 inString: vString withColor: vColor andMode: vComponentName];
			}
			else if( [vComponentType isEqualToString: @"String"] )
			{
				[self colorStringsFrom: [vCurrComponent objectForKey: @"Start"]
									to: [vCurrComponent objectForKey: @"End"]
							  inString: vString withColor: vColor andMode: vComponentName
						 andEscapeChar: [vCurrComponent objectForKey: @"EscapeChar"]]; 
			}
			else if( [vComponentType isEqualToString: @"Tag"] )
			{
				[self colorTagFrom: [vCurrComponent objectForKey: @"Start"]
								to: [vCurrComponent objectForKey: @"End"] inString: vString
						 withColor: vColor andMode: vComponentName
					  exceptIfMode: [vCurrComponent objectForKey: @"IgnoredComponent"]];
			}
			else if( [vComponentType isEqualToString: @"Keywords"] )
			{
				NSArray* vIdents = [vCurrComponent objectForKey: @"Keywords"];
				if( !vIdents )
					vIdents = [[NSUserDefaults standardUserDefaults] objectForKey: [@"SyntaxColoring:Keywords:" stringByAppendingString: vComponentName]];
				if( !vIdents && [vComponentName isEqualToString: @"UserIdentifiers"] )
					vIdents = [[NSUserDefaults standardUserDefaults] objectForKey: TD_USER_DEFINED_IDENTIFIERS];
				if( vIdents )
				{
					NSCharacterSet*		vIdentCharset = nil;
					NSString*			vCurrIdent = nil;
					NSString*			vCsStr = [vCurrComponent objectForKey: @"Charset"];
					if( vCsStr )
						vIdentCharset = [NSCharacterSet characterSetWithCharactersInString: vCsStr];
					
					NSEnumerator*	vItty = [vIdents objectEnumerator];
					while( vCurrIdent = [vItty nextObject] )
						[self colorIdentifier: vCurrIdent inString: vString withColor: vColor
									  andMode: vComponentName charset: vIdentCharset];
				}
			}
		}
		
		// Replace the range with our recolored part:
		[vString addAttributes: vStyles range: NSMakeRange( 0, [vString length] )];
		[[self textStorage] replaceCharactersInRange: range withAttributedString: vString];
		[[self textStorage] fixFontAttributeInRange:range];
		
	NS_HANDLER

		[localException raise];
	NS_ENDHANDLER
}



#pragma mark -
#pragma mark Minor support

/* -----------------------------------------------------------------------------
	syntaxDefinitionDictionary:
		This returns the syntax definition dictionary to use, which indicates
		what ranges of text to colorize. Advanced users may use this to allow
		different coloring to take place depending on the file extension by
		returning different dictionaries here.
		
		Hard wired to return a static for now, since this is all we'll need.

   -------------------------------------------------------------------------- */

-(NSDictionary*)	syntaxDefinitionDictionary
{
	static NSDictionary *sSyntaxDefinitionDictionary = nil;
	if (nil == sSyntaxDefinitionDictionary)
	{
		sSyntaxDefinitionDictionary = [[NSDictionary alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource:@"HTMLSyntaxColoring" ofType:@"plist"]];
	}
	return sSyntaxDefinitionDictionary;
}

/* -----------------------------------------------------------------------------
defaultTextAttributes:
Return the text attributes to use for the text in our text view.

REVISIONS:
2004-05-18  witness Documented.
-------------------------------------------------------------------------- */

static NSMutableDictionary *sDefaultTextAttributesPerInstance = nil;

+ (void) startRecordingFontChanges;
{
	if (nil == sDefaultTextAttributesPerInstance)
	{
		sDefaultTextAttributesPerInstance = [[NSMutableDictionary alloc] init];
	}
}

-(NSDictionary *) defaultTextAttributes
{
	NSDictionary *result = nil;
	// fallback
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	if (nil != sDefaultTextAttributesPerInstance)
	{
		NSString *keyForSelf = [NSString stringWithFormat:@"%p", self];
		NSDictionary *valueForSelf = nil;
		if (nil != (valueForSelf = [sDefaultTextAttributesPerInstance objectForKey:keyForSelf]) )
		{
			result = valueForSelf;
		}
	}
	if (nil == result)	// don't have a setting yet, use defaults
	{
		NSString *fontName = [defaults objectForKey:@"HTMLViewFontName"];
		float pointSize = [defaults floatForKey:@"HTMLViewPointSize"];
		
		NSFont *font = nil;
		if (fontName) {
			font = [NSFont fontWithName:fontName size:pointSize];
		}
		if (!font) {
			font = [NSFont userFixedPitchFontOfSize:10.0];
		}
		
		result = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
		
		// Now, store so that we can get it quickly next time.
		[self setDesiredAttributes:result];
	}
	return result;
}

- (void) setDesiredAttributes:(NSDictionary *)attr;
{
	if (sDefaultTextAttributesPerInstance)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		NSFont *font = [attr objectForKey:NSFontAttributeName];
		if (font)
		{
			// store in defaults for next time
			[defaults setObject:[font fontName] forKey:@"HTMLViewFontName"];
			[defaults setObject:[NSNumber numberWithFloat:[font pointSize]] forKey:@"HTMLViewPointSize"];
			[defaults synchronize];
		
			// store in registry
			NSString *keyForSelf = [NSString stringWithFormat:@"%p", self];
			NSDictionary *newAttr = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
			[sDefaultTextAttributesPerInstance setObject:newAttr forKey:keyForSelf];
		}
	}
}



/* -----------------------------------------------------------------------------
turnOffWrapping:
Makes the view so wide that text won't wrap anymore.
-------------------------------------------------------------------------- */

-(void) turnOffWrapping
{
	const float			LargeNumberForText = 1.0e7;
	NSTextContainer*	textContainer = [self textContainer];
	NSRect				frame;
	NSScrollView*		scrollView = [self enclosingScrollView];
	
	// Make sure we can see right edge of line:
    [scrollView setHasHorizontalScroller:YES];
	
	// Make text container so wide it won't wrap:
	[textContainer setContainerSize: NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[textContainer setWidthTracksTextView:NO];
    [textContainer setHeightTracksTextView:NO];
	
	// Make sure text view is wide enough:
	frame.origin = NSMakePoint(0.0, 0.0);
    frame.size = [scrollView contentSize];
	
    [self setMaxSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
    [self setHorizontallyResizable:YES];
    [self setVerticallyResizable:YES];
    [self setAutoresizingMask:NSViewNotSizable];
}


#pragma mark -
#pragma mark Coloring support


/* -----------------------------------------------------------------------------
	colorStringsFrom:
		Apply syntax coloring to all strings. This is basically the same code
		as used for multi-line comments, except that it ignores the end
		character if it is preceded by a backslash.
   -------------------------------------------------------------------------- */

-(void)	colorStringsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
							withColor: (NSColor*) col andMode:(NSString*)attr andEscapeChar: (NSString*)vStringEscapeCharacter
{
	NS_DURING
		NSString *sString = [s string];
		if (!sString) return;
	
		NSScanner*					vScanner = [NSScanner scannerWithString: sString];
		NSDictionary*				vStyles = [NSDictionary dictionaryWithObjectsAndKeys:
													col, NSForegroundColorAttributeName,
													attr, TD_SYNTAX_COLORING_MODE_ATTR,
													nil];
		BOOL						vIsEndChar = NO;
		unichar						vEscChar = '\\';
		
		if( vStringEscapeCharacter )
		{
			if( [vStringEscapeCharacter length] != 0 )
				vEscChar = [vStringEscapeCharacter characterAtIndex: 0];
		}
		
		while( ![vScanner isAtEnd] )
		{
			int		vStartOffs,
					vEndOffs;
			vIsEndChar = NO;
			
			// Look for start of string:
			[vScanner scanUpToRealString: startCh intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( ![vScanner scanRealString:startCh intoString:nil] )
				NS_VOIDRETURN;

			while( !vIsEndChar && ![vScanner isAtEnd] )	// Loop until we find end-of-string marker or our text to color is finished:
			{
				[vScanner scanUpToRealString: endCh intoString: nil];
				if( ([vStringEscapeCharacter length] == 0) || [[s string] characterAtIndex: ([vScanner scanLocation] -1)] != vEscChar )	// Backslash before the end marker? That means ignore the end marker.
					vIsEndChar = YES;	// A real one! Terminate loop.
				if( ![vScanner scanRealString:endCh intoString:nil] )	// But skip this char before that.
					NS_VOIDRETURN;
				
			}
			
			vEndOffs = [vScanner scanLocation];
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
		}
	NS_HANDLER
		// Just ignore it, syntax coloring isn't that important.
	NS_ENDHANDLER
}


/* -----------------------------------------------------------------------------
	colorCommentsFrom:
		Colorize block-comments in the text view.
	
	REVISIONS:
		2004-05-18  witness Documented.
   -------------------------------------------------------------------------- */

-(void)	colorCommentsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
							withColor: (NSColor*) col andMode:(NSString*)attr
{
	NS_DURING
		NSString *sString = [s string];
		if (!sString) return;
	
		NSScanner*					vScanner = [NSScanner scannerWithString: sString];
		NSDictionary*				vStyles = [NSDictionary dictionaryWithObjectsAndKeys:
													col, NSForegroundColorAttributeName,
													attr, TD_SYNTAX_COLORING_MODE_ATTR,
													nil];
		
		while( ![vScanner isAtEnd] )
		{
			int		vStartOffs,
					vEndOffs;
			
			// Look for start of multi-line comment:
			[vScanner scanUpToRealString: startCh intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( ![vScanner scanRealString:startCh intoString:nil] )
				NS_VOIDRETURN;

			// Look for associated end-of-comment marker:
			[vScanner scanUpToRealString: endCh intoString: nil];
			if( ![vScanner scanRealString:endCh intoString:nil] )
			{
				/*NS_VOIDRETURN*/;  // Don't exit. If user forgot trailing marker, indicate this by "bleeding" until end of string.
			}
			vEndOffs = [vScanner scanLocation];
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
				
		}
	NS_HANDLER
		// Just ignore it, syntax coloring isn't that important.
	NS_ENDHANDLER
}


/* -----------------------------------------------------------------------------
	colorOneLineComment:
		Colorize one-line-comments in the text view.
	
	REVISIONS:
		2004-05-18  witness Documented.
   -------------------------------------------------------------------------- */

-(void)	colorOneLineComment: (NSString*) startCh inString: (NSMutableAttributedString*) s
				withColor: (NSColor*) col andMode:(NSString*)attr
{
	NS_DURING
		NSString *sString = [s string];
		if (!sString) return;

		NSScanner*					vScanner = [NSScanner scannerWithString: sString];
		NSDictionary*				vStyles = [NSDictionary dictionaryWithObjectsAndKeys:
													col, NSForegroundColorAttributeName,
													attr, TD_SYNTAX_COLORING_MODE_ATTR,
													nil];
		
		while( ![vScanner isAtEnd] )
		{
			int		vStartOffs,
					vEndOffs;
			
			// Look for start of one-line comment:
			[vScanner scanUpToRealString: startCh intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( ![vScanner scanRealString:startCh intoString:nil] )
				NS_VOIDRETURN;

			// Look for associated line break:
			if( ![vScanner skipUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString: @"\n\r"]] )
				;
			
			vEndOffs = [vScanner scanLocation];
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
				
		}
	NS_HANDLER
		// Just ignore it, syntax coloring isn't that important.
	NS_ENDHANDLER
}


/* -----------------------------------------------------------------------------
	colorIdentifier:
		Colorize keywords in the text view.
	
	REVISIONS:
		2004-05-18  witness Documented.
   -------------------------------------------------------------------------- */

-(void)	colorIdentifier: (NSString*) ident inString: (NSMutableAttributedString*) s
			withColor: (NSColor*) col andMode:(NSString*)attr charset: (NSCharacterSet*)cset
{
	NS_DURING
		NSString *sString = [s string];
		if (!sString) return;

		NSScanner*					vScanner = [NSScanner scannerWithString: sString];
		NSDictionary*				vStyles = [NSDictionary dictionaryWithObjectsAndKeys:
													col, NSForegroundColorAttributeName,
													attr, TD_SYNTAX_COLORING_MODE_ATTR,
													nil];
		int							vStartOffs = 0;
		
		// Skip any leading whitespace chars, somehow NSScanner doesn't do that:
		if( cset )
		{
			while( vStartOffs < [[s string] length] )
			{
				if( [cset characterIsMember: [[s string] characterAtIndex: vStartOffs]] )
					break;
				vStartOffs++;
			}
		}
		
		[vScanner setScanLocation: vStartOffs];
		
		while( ![vScanner isAtEnd] )
		{
			// Look for start of identifier:
			[vScanner scanUpToRealString: ident intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( ![vScanner scanRealString:ident intoString:nil] )
			{
				NS_VOIDRETURN;
			}
			
			if( vStartOffs > 0 )	// Check that we're not in the middle of an identifier:
			{
				// Alphanum character before identifier start?
				if( [cset characterIsMember: [[s string] characterAtIndex: (vStartOffs -1)]] )  // If charset is NIL, this evaluates to NO.
					continue;
			}
			
			if( (vStartOffs +[ident length] +1) < [s length] )
			{
				// Alphanum character following our identifier?
				if( [cset characterIsMember: [[s string] characterAtIndex: (vStartOffs +[ident length])]] )  // If charset is NIL, this evaluates to NO.
					continue;
			}
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, [ident length] )];
				
		}
		
	NS_HANDLER
		// Just ignore it, syntax coloring isn't that important.
	NS_ENDHANDLER
}


/* -----------------------------------------------------------------------------
	colorTagFrom:
		Colorize HTML tags or similar constructs in the text view.
	
	REVISIONS:
		2004-05-18  witness Documented.
   -------------------------------------------------------------------------- */

-(void)	colorTagFrom: (NSString*) startCh to: (NSString*)endCh inString: (NSMutableAttributedString*) s
				withColor: (NSColor*) col andMode:(NSString*)attr exceptIfMode: (NSString*)ignoreAttr
{
	NS_DURING
		NSString *sString = [s string];
		if (!sString) return;

		NSScanner*					vScanner = [NSScanner scannerWithString: sString];
		NSDictionary*				vStyles = [NSDictionary dictionaryWithObjectsAndKeys:
													col, NSForegroundColorAttributeName,
													attr, TD_SYNTAX_COLORING_MODE_ATTR,
													nil];
		
		while( ![vScanner isAtEnd] )
		{
			int		vStartOffs,
					vEndOffs;
			
			// Look for start of one-line comment:
			[vScanner scanUpToRealString: startCh intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( vStartOffs >= [s length] )
				NS_VOIDRETURN;
			NSString*   scMode = [[s attributesAtIndex:vStartOffs effectiveRange: nil] objectForKey: TD_SYNTAX_COLORING_MODE_ATTR];
			if( ![vScanner scanRealString:startCh intoString:nil] )
				NS_VOIDRETURN;
			
			// If start lies in range of ignored style, don't colorize it:
			if( ignoreAttr != nil && [scMode isEqualToString: ignoreAttr] )
				continue;

			// Look for matching end marker:
			while( ![vScanner isAtEnd] )
			{
				// Scan up to the next occurence of the terminating sequence:
				(BOOL) [vScanner scanUpToRealString: endCh intoString:nil];
				
				// Now, if the mode of the end marker is not the mode we were told to ignore,
				//  we're finished now and we can exit the inner loop:
				vEndOffs = [vScanner scanLocation];
				if( vEndOffs < [s length] )
				{
					scMode = [[s attributesAtIndex:vEndOffs effectiveRange: nil] objectForKey: TD_SYNTAX_COLORING_MODE_ATTR];
					[vScanner scanRealString: endCh intoString: nil];   // Also skip the terminating sequence.
					if( ignoreAttr == nil || ![scMode isEqualToString: ignoreAttr] )
						break;
				}
				
				// Otherwise we keep going, look for the next occurence of endCh and hope it isn't in that style.
			}
			
			vEndOffs = [vScanner scanLocation];
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
				
		}
	NS_HANDLER
		// Just ignore it, syntax coloring isn't that important.
	NS_ENDHANDLER
}

@end
