//
//  KTImageView.h
//  KTComponents
//
//  Copyright 2005-2011 Karelia Software. All rights reserved.
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


@class ImageCropperController;
@class NSImagePickerController;


@interface KTImageView : NSImageView
{
	// set one or the other, delegate is checked first
    IBOutlet id delegate;
	IBOutlet NSObjectController *oDelegateController;
	
	NSString	*myWindowTitle;
	NSDictionary *myDataSourceDictionary;
	
//	ImageCropperController *myImageCropperController;
//	NSImagePickerController *myPickController;

  @private
    NSPasteboard    *_pasteboard;   // weak ref
}

// During a paste or drop, this will return the pasteboard it's sourced from
- (NSPasteboard *)editPasteboard;

// Accessors
- (NSDictionary *)dataSourceDictionary;
- (void)setDataSourceDictionary:(NSDictionary *)aDataSourceDictionary;

- (id)delegate;
- (void)setDelegate:(id)aDelegate;

- (NSString *)windowTitle;
- (void)setWindowTitle:(NSString *)aWindowTitle;

// Also, image / setImage is part of NSImageView

// Delegate communication

/*! tells delegate to set to a media object with kKTDataSourceNil */
- (IBAction)removeImage:(id)sender;

@end

@interface NSObject ( KTImageViewDelegate )
- (void)imageView:(KTImageView *)anImageView setWithDataSourceDictionary:(NSDictionary *)aDataSourceDictionary;
- (NSImage *)imageForImageView:(KTImageView *)anImageView;
@end

/*

- (IBAction)pickSomeone:(id)sender;
- (IBAction)choseSomeone:(id)sender;
- (IBAction)changeSelection:(id)sender;

- (void)imagePicker:sender selectedImage:(NSImage *)image;
- (void)imagePickerCanceled:sender;

*/
