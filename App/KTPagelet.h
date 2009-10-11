//
//  KTPagelet.h
//  Sandvox
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
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

#import "KTAbstractElement.h"


typedef enum {
	KTSidebarPageletLocation = 1,
	KTCalloutPageletLocation = 3,
	KTTopSidebarPageletLocation = 11,
	KTBottomSidebarPageletLocation,
} KTPageletLocation;


@class KTPage, SVPageletBody;
@interface KTPagelet : KTAbstractElement

#pragma mark Basic accessors

- (int)ordering;

- (BOOL)shouldPropagate;
- (void)setShouldPropagate:(BOOL)propagate;

- (NSString *)introductionHTML;
- (void)setIntroductionHTML:(NSString *)value;

- (BOOL)showBorder;
- (void)setShowBorder:(BOOL)flag;

- (KTPage *)page;
- (NSSet *)allPages;


#pragma mark Location

- (KTPageletLocation)location;
- (KTPageletLocation)locationByDifferentiatingTopAndBottomSidebars;
- (void)setLocation:(KTPageletLocation)location;

- (BOOL)prefersBottom;
- (void)setPrefersBottom:(BOOL)prefersBottom;

- (BOOL)canMoveUp;
- (BOOL)canMoveDown;
- (void)moveUp;
- (void)moveDown;

- (NSArray *)pageletsInSameLocation;

@end
