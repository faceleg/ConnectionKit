//
//  KTHTMLInspectorController.h




//  originally
//  Created by Uli Kusterer on Tue May 27 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//


#import <Cocoa/Cocoa.h>


@class KTAbstractElement;

// Syntax-colored text file viewer:
@interface KTHTMLInspectorController : NSWindowController
{
	IBOutlet NSTextView*			textView;				// The text view used for editing code.
    NSUndoManager                   *myUndoManager;
	
	// Not really hooked up!
	IBOutlet NSProgressIndicator*	progress;				// Progress indicator while coloring syntax.
	IBOutlet NSTextField*			status;					// Status display for things like syntax coloring or background syntax checks.

	
@private	
	BOOL							autoSyntaxColoring;		// Automatically refresh syntax coloring when text is changed?
	BOOL							maintainIndentation;	// Keep new lines indented at same depth as their predecessor?
	NSTimer*						recolorTimer;			// Timer used to do the actual recoloring a little while after the last keypress.
	BOOL							syntaxColoringBusy;		// Set while recolorRange is busy, so we don't recursively call recolorRange.
	NSRange							affectedCharRange;
	NSString*						replacementString;

	// ivar of what to send the information back to
	NSObject			*myHTMLSourceObject;
	NSString			*myHTMLSourceKeyPath;
	BOOL				fromEditableBlock;
	
	NSString			*mySourceCode;				// Temp. storage for data from file until NIB has been read.
	NSString			*myTitle;
	NSString			*myExplanation;
	
	NSTimeInterval		myLastEditTime;				// keep track of keystroke/replace changes to not lose search/replaces
}

- (void)setSourceCode:(NSString *)aString;	// problem is, where does it go when it's edited?

- (NSString *)explanation;
- (void)setExplanation:(NSString *)anExplanation;
- (NSString *)sourceCode;
- (void)setSourceCode:(NSString *)aSourceCode;
- (NSString *)title;
- (void)setTitle:(NSString *)aTitle;
- (IBAction) windowHelp:(id)sender;

- (NSObject *)HTMLSourceObject;
- (void)setHTMLSourceObject:(NSObject *)anHTMLSourceObject;
- (NSString *)HTMLSourceKeyPath;
- (void)setHTMLSourceKeyPath:(NSString *)anHTMLSourceKeyPath;
- (BOOL)fromEditableBlock;
- (void)setFromEditableBlock:(BOOL)flag;









@end



// Support for external editor interface:
//	(Doesn't really work yet ... *sigh*)

#pragma options align=mac68k

struct SelectionRange
{
	short   unused1;	// 0 (not used)
	short   lineNum;	// line to select (< 0 to specify range)
	long	startRange; // start of selection range (if line < 0)
	long	endRange;   // end of selection range (if line < 0)
	long	unused2;	// 0 (not used)
	long	theDate;	// modification date/time
};

#pragma options align=reset

