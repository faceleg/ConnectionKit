//
//  CIImage+KTExtensions.h
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

typedef enum {
		kAutomatic, kAnamorphic, kFitWithinRect, kCoverRect, kCropToRect
} CIScalingBehavior;


@class KTImageScalingSettings;

	
@interface CIImage (KTExtensions)

+ (NSArray *)imageTypes;

- (NSImage *)toNSImage;
-(NSImage *)toNSImageBitmap;	// like above, but forces a bitmap image rep, not NSCIImageRep
- (NSImage *)toNSImageFromRect:(CGRect)r;
-(NSBitmapImageRep *)bitmap;

- (CIImage *)scaleToWidth:(float)aWidth
				   height:(float)aHeight
				 behavior:(CIScalingBehavior)aBehavior	// if kAutomatic, above can be zero
				alignment:(NSImageAlignment)anAlignment	// applies for kCropToRect, 0 otherwise
			   opaqueEdges:(BOOL)anOpaqueEdges;			// makes sure edges are not transparent

- (CIImage *)imageByApplyingScalingSettings:(KTImageScalingSettings *)settings;

- (CIImage *)sharpenLuminanceWithFactor:(float)aSharpness;	// range 0.0 to 2.0

- (CIImage *)rotateDegrees:(float)aDegrees;	// range 0.0 to 360.0

- (CIImage *)addWhiteBorder:(int)aPixels;

- (CIImage *)addShadow:(int)aPixels;	// pixels in blurriness and affects offset

@end
