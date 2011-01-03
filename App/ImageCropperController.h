//
//  ImageCropperController.h
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

@class CroppingImageView;

@interface ImageCropperController : NSWindowController {

	id myDelegate;	// not retained
	
	IBOutlet NSObjectController *oController;
	IBOutlet NSSlider *oZoomSlider;
	IBOutlet CroppingImageView *oCroppingImageView;
	
	NSImage *myOriginalImage;
	NSString *myOriginalImagePath;		// path of original file, since that's "purer" in case the image is not cropped
	
	NSImage *myCroppedImage;
}

+ (ImageCropperController *)sharedImageCropperControllerCreate:(BOOL)aCreate;
- (CroppingImageView *)croppingImageView;


- (void)reset;

- (IBAction) doOK:(id)sender;
- (IBAction) doCancel:(id)sender;
- (IBAction) chooseFile:(id)sender;
- (IBAction) zoomOut:(id)sender;
- (IBAction) zoomIn:(id)sender;


- (NSImage *)originalImage;
- (void)setOriginalImage:(NSImage *)anOriginalImage;

- (NSString *)originalImagePath;
- (void)setOriginalImagePath:(NSString *)anOriginalImagePath;

- (NSImage *)croppedImage;


- (id)delegate;
- (void)setDelegate:(id)aDelegate;

@end

@interface NSObject ( ImageCropperController )
- (void)imagePickerSet:(id)sender;
- (void)imagePickerCancelled:(id)sender;
@end
