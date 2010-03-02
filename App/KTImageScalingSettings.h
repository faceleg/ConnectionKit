//
//  KTImageScalingSettings.h
//  Sandvox
//
//  Copyright 2008-2009 Karelia Software. All rights reserved.
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
	KTScaleByFactor,
	KTScaleToSize,
	KTCropToSize,
	KTStretchToSize,
} KTMediaScalingOperation;


@interface KTImageScalingSettings : NSObject <NSCoding>
{
	@private
	
	KTMediaScalingOperation	myBehaviour;
	NSSize					_size;
	float					myScaleFactor;
	NSImageAlignment		myImageAlignment;
}

// Init
+ (id)settingsWithScaleFactor:(float)scaleFactor;

+ (id)settingsWithBehavior:(KTMediaScalingOperation)behavior size:(NSSize)size;

+ (id)cropToSize:(NSSize)size alignment:(NSImageAlignment)alignment;

+ (id)scalingSettingsWithDictionaryRepresentation:(NSDictionary *)dictionary;

// Accessors
- (KTMediaScalingOperation)behavior;
- (NSSize)size;
- (float)scaleFactor;
- (NSImageAlignment)alignment;

// Equality
- (BOOL)isEqual:(id)anObject;
- (BOOL)isEqualToImageScalingSettings:(KTImageScalingSettings *)settings;
- (unsigned)hash;

// Resizing
- (NSRect)sourceRectForImageOfSize:(NSSize)sourceSize;

- (float)scaleFactorForImageOfSize:(CGSize)sourceSize;
- (float)aspectRatioForImageOfSize:(CGSize)sourceSize;
- (NSSize)scaledSizeForImageOfSize:(NSSize)sourceSize;
- (CGSize)scaledCGSizeForImageOfSize:(CGSize)sourceSize;

//- (NSSize)destinationSizeForImageOfSize:(NSSize)sourceSize;
//- (float)heightForImageOfSize:(NSSize)sourceSize;

@end
