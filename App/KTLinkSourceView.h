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


@protocol KTLinkSourceViewDelegate;


@interface KTLinkSourceView : NSView 
{
	IBOutlet id <KTLinkSourceViewDelegate> delegate; // not retained
	
	struct __ktDelegateFlags {
		unsigned begin: 1;
		unsigned end: 1;
		unsigned ui: 1;
		unsigned isConnecting: 1;
		unsigned isConnected: 1;
		unsigned unused: 27;
	} myFlags;
}

- (void)setConnected:(BOOL)isConnected;

- (void)setDelegate:(id <KTLinkSourceViewDelegate>)delegate;
- (id <KTLinkSourceViewDelegate>)delegate;

@end


@protocol KTLinkSourceViewDelegate <NSObject>
- (NSPasteboard *)linkSourceDidBeginDrag:(KTLinkSourceView *)link;
- (void)linkSourceDidEndDrag:(KTLinkSourceView *)link withPasteboard:(NSPasteboard *)pboard;
- (id)userInfoForLinkSource:(KTLinkSourceView *)link;
@end


extern NSString *kKTLocalLinkPboardType;

