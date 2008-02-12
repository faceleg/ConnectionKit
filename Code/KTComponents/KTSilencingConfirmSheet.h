//
//  KTSilencingConfirmSheet.h
//  KTComponents
//
//  Copyright (c) 2005-2006, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>


// trampoline-like object

@interface KTSilencingConfirmSheet : NSObject {
	
	IBOutlet NSButton		*oCancelButton;
	IBOutlet NSButton		*oOKButton;
	IBOutlet NSWindow		*oSheetWindow;
	IBOutlet NSButton		*oSilenceCheckbox;
	IBOutlet NSTextField	*oTitleText;
	IBOutlet NSTextView		*oMessageTextView;
	
	id				myTarget;
	NSString		*mySilencingDefaultsKey;
	NSWindow		*myParentWindow;
    NSInvocation	*myInvocation;
}

+ (void) alertWithWindow:(NSWindow *)aWindow silencingKey:(NSString *)aSilencingKey title:(NSString *)aTitle format:(NSString *)format, ...;

- (IBAction)sheetOK: (id)sender;
- (IBAction)sheetCancel: (id)sender;

@end

@interface NSObject ( KTSilencingConfirmSheet )

/*!	Call your method like this:

[[self confirmWithWindow:[self window] silencingKey:@"shutUpTest" canCancel:YES OKButton:@"Yep" silence:@"Always do this thing" title:@"This is the Title" format:@"There are %d in a dozen", 12] doSomeTest:42];

This should be called at the end of an event handler, since the actual invocation may be delayed.

*/
- (id)confirmWithWindow:(NSWindow *)aWindow silencingKey:(NSString *)aSilencingKey canCancel:(BOOL)aCanCancel OKButton:(NSString *)anOKTitle silence:(NSString *)aSilenceTitle title:(NSString *)aTitle format:(NSString *)format, ...;

@end
