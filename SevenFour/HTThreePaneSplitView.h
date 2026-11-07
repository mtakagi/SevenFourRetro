//
//  HTThreePaneSplitView.h
//  HTThreePaneSplitView
//
//  Created by hetima on 05/5/28.
//  Copyright 2005 hetima. All rights reserved.
//
//  version 20050725

#import <Cocoa/Cocoa.h>


/*
NSDictionary* _layoutInfo{
	sideViewRatio=float;
	sideViewtWidth=float;
	topViewRatio=float;
	topViewStretch=float;

	sideIsRight=BOOL;
	isVertical=BOOL; //とりあえず実装
	
	sideViewNeedsBorder=BOOL;
	topViewNeedsBorder=BOOL;
	bottomViewNeedsBorder=BOOL;
}
*/
#define kHTTPVSideViewDefaultRatio 0.2
#define kHTTPVTopViewDefaultRatio 0.4
#define kHTTPVTopViewSeparatorThickness 4

#define kSideViewMinWidth 40


@interface HTThreePaneSplitView : NSView {
	NSMutableDictionary* _layoutInfo;

	NSRect	_sideSpliterRect;
	NSRect	_mainSpliterRect;
	NSPoint _trackingStartPoint;
	int		_trackingMode;
//	float	_sideViewBestWidth;
	NSString*	_autosaveName;
	NSView*	_oldView;

	IBOutlet id delegate;
	IBOutlet NSView* sideView; //can be nil
	IBOutlet NSView* topView;
	IBOutlet NSView* bottomView;

}

// subview
// addSubview: による view 階層の retain のみされる

// sideView を外したいときは setSideView:nil する
// 元の sideView は view 階層から外され、release される。
// 付けたり外したりする場合は、別のクラスで管理してくださいね
- (NSView*)sideView;
- (void)setSideView:(NSView*)view; //IBOutlet
- (NSView*)topView;
- (void)setTopView:(NSView*)view;  //IBOutlet
- (NSView*)bottomView;
- (void)setBottomView:(NSView*)view;  //IBOutlet


// スタイル
- (void) useSideViewAlternativeStyle: (BOOL) flag;
- (BOOL) sideViewAlternativeStyle;
// 枠を描く必要があるかどうか デフォルトは NO
// NSTextView や NSTableView などは枠があるので NO のままで良い
- (BOOL)sideViewNeedsBorder;
- (void)setSideViewNeedsBorder:(BOOL)flag;
- (BOOL)topViewNeedsBorder;
- (void)setTopViewNeedsBorder:(BOOL)flag;
- (BOOL)bottomViewNeedsBorder;
- (void)setBottomViewNeedsBorder:(BOOL)flag;

- (void) showBottomView: (BOOL) flag;
- (void) showSideView: (BOOL) flag;
- (BOOL) isSideViewVisible;

// IBAction
- (IBAction)toggleVertical:(id)sender;
- (IBAction)toggleSideViewPosition:(id)sender;
- (IBAction) toggleSideView: (id) sender;
- (IBAction) toggleBottomView: (id) sender;

// access
- (BOOL)sideIsRight;
- (void)setSideIsRight:(BOOL)flag;
- (BOOL)isVertical;	//とりあえず実装
- (void)setVertical:(BOOL)flag; //とりあえず実装
// separatorを動かすときにスナップする 未実装
//- (float)sideViewBestWidth;
//- (void)setSideViewBestWidth:(float)inValue;

// UderDefaults用。
// awakeFromNib あたりで setAutosaveName: を呼ぶ
- (NSString *)autosaveName;
- (void)setAutosaveName:(NSString *)name;
//こっちは使わなくて良い
- (NSDictionary*)layoutInfo;
- (void)setLayoutInfo:(NSDictionary*)pref;

// delegate
// toggleSideViewPosition: すると、
// - (void)threePaneSplitViewWillChangeSideViewPosition:(HTThreePaneSplitView*)splitView;
// が呼ばれる
- (id)delegate;
- (void)setDelegate:(id)obj;



//private
- (void)_setUpDefaultLayoutInfo;
- (NSString *)autosaveNamePrefix;
- (void)_loadLayoutInfo;
- (void)_saveLayoutInfo;
//- (unsigned int)_currentAutoresizingMaskForSideView;
//- (unsigned int)_currentAutoresizingMaskForTopView;
//- (unsigned int)_currentAutoresizingMaskForBottomView;
- (void)_adjustLayout;
@end


@interface NSObject (HTThreePaneSplitViewDelegate)
- (void)threePaneSplitViewWillChangeSideViewPosition:(HTThreePaneSplitView*)splitView;
- (void)threePaneSplitViewWillChangeVartical:(HTThreePaneSplitView*)splitView;
@end


@interface HTThreePaneSplitView (SpliterUISupport)
+ (NSImage*)verticalPatternImage;
+ (NSImage*)horizontalPatternImage;
+ (NSImage*)dimpleImage;
- (void)drawSpliterWithFrame:(NSRect)cellFrame firstViewNeedsBorder:(BOOL)fBorder secondViewNeedsBorder:(BOOL)sBorder;
@end
