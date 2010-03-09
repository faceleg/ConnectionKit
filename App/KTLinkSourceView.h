//
//  KTLinkSourceView.h
//  Sandvox
//
//  Copyright 2006-2009 Karelia Software. All rights reserved.
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

@class KTPage;

@protocol KTLinkSourceViewDelegate;


@interface KTLinkSourceView : NSView 
{
	BOOL _collectionsOnly;	// controller should set this in awakeFromNib.
	NSWindow *_targetWindow;	// NSWindow that we are allowed to drag into.

	KTPage *_connectedPage;	// set when done connecting, use bindings or delegate method to find out
	
	
	
	IBOutlet id <KTLinkSourceViewDelegate> _delegate; // not retained
	
	struct __ktDelegateFlags {
		unsigned begin: 1;
		unsigned end: 1;
		unsigned ui: 1;
		unsigned isConnecting: 1;
		unsigned isConnected: 1;
		unsigned unused: 27;
	} _flags;
}

@property (assign) BOOL collectionsOnly;
@property (copy) NSWindow *targetWindow;
@property (copy) KTPage *connectedPage;
@property (assign) id <KTLinkSourceViewDelegate> delegate;

- (void)setConnected:(BOOL)isConnected;

@end


@protocol KTLinkSourceViewDelegate <NSObject>
- (void)linkSourceConnectedTo:(KTPage *)aPage;
@end


extern NSString *kKTLocalLinkPboardReturnType;
extern NSString *kKTLocalLinkPboardAllowedType;

