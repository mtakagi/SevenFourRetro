//
//  HTThreePaneSplitView.m
//  HTThreePaneSplitView
//
//  Created by hetima on 05/5/28.
//  Copyright 2005 hetima. All rights reserved.
//
//  version 20050725

#import "HTThreePaneSplitView.h"

#define kInvalidSpliterTracking 0
#define kSideSpliterTracking 1
#define kMainSpliterTracking 2
#define kMainSpliterTrackingVertical 3

#define kHTTPVPrefVersion 1

@implementation HTThreePaneSplitView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.

		[self _setUpDefaultLayoutInfo];
    }
    return self;
}


- (void)dealloc {
	[_layoutInfo release];
	[_autosaveName autorelease];
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect {
    // Drawing code here.
	
	//spliter を描く
	BOOL	topBorder=[self topViewNeedsBorder];
	BOOL	bottomBorder=[self bottomViewNeedsBorder];
	BOOL	sideIsRight=[self sideIsRight];
	if([self isSideViewVisible]){
		BOOL firstBorder, secondBorder;
		if(sideIsRight){
			firstBorder=YES;//(topBorder || bottomBorder);
			secondBorder=[self sideViewNeedsBorder];
		}else{
			firstBorder=[self sideViewNeedsBorder];
			secondBorder=YES;//(topBorder || bottomBorder);
		}
        
        [[NSColor controlShadowColor] set];
        NSRect frame = [sideView frame];
        frame.origin.x = -1;
        frame.origin.y = -1;
        frame.size.width += 2;
        frame.size.height += 2 + 24;
        NSFrameRect(frame);

        [self drawSpliterWithFrame:_sideSpliterRect
              firstViewNeedsBorder:firstBorder secondViewNeedsBorder:secondBorder];
	}
	
	[self drawSpliterWithFrame:_mainSpliterRect
			firstViewNeedsBorder:topBorder secondViewNeedsBorder:bottomBorder];
	
}

- (void)willRemoveSubview:(NSView *)subview
{
	BOOL isManagementView=NO;
	
	if(subview==_oldView){
		//アクセッサで外したのなら何もしなくて良い

	}else if(subview==sideView){
		sideView=nil;
		isManagementView=YES;
	}else if(subview==topView){
		topView=nil;
	}else if(subview==bottomView){
		bottomView=nil;
	}
	
	[super willRemoveSubview:subview];
	
	if(isManagementView){
		[self _adjustLayout];
	}
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{
	[self _adjustLayout];
	//[super resizeSubviewsWithOldSize:oldBoundsSize];
}

- (void)resetCursorRects
{
	if(_sideSpliterRect.size.height>1)
		[self addCursorRect:_sideSpliterRect cursor:[NSCursor resizeLeftRightCursor]];
	if(_mainSpliterRect.size.width>1){
		NSCursor*	mainSpliterCursor=nil;
		if(_mainSpliterRect.size.width>_mainSpliterRect.size.height){
			mainSpliterCursor=[NSCursor resizeUpDownCursor];
		}else{
			mainSpliterCursor=[NSCursor resizeLeftRightCursor];
		}
		[self addCursorRect:_mainSpliterRect cursor:mainSpliterCursor];
	}
}

#pragma mark -
- (void)mouseDown:(NSEvent *)theEvent
{
    _trackingStartPoint=[theEvent locationInWindow];
	if(NSPointInRect(_trackingStartPoint,_sideSpliterRect)){
		_trackingMode=kSideSpliterTracking;
	}else if(NSPointInRect(_trackingStartPoint,_mainSpliterRect)){
		if([self isVertical]){
			_trackingMode=kMainSpliterTrackingVertical;
		}else{
			_trackingMode=kMainSpliterTracking;
		}
	}else{
		_trackingMode=kInvalidSpliterTracking;
	}
}

- (void)mouseUp:(NSEvent *)theEvent;
{
	if(_trackingMode!=kInvalidSpliterTracking){
		[self _saveLayoutInfo];
	}
	_trackingMode=kInvalidSpliterTracking;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if(_trackingMode==kInvalidSpliterTracking)return;

    NSPoint currentPoint=[theEvent locationInWindow];
    float   dy=currentPoint.y-_trackingStartPoint.y;
    float   dx=currentPoint.x-_trackingStartPoint.x;
	NSRect  topViewFrame=[topView frame];
	NSRect  bottomViewFrame=[bottomView frame];
	NSSize	selfSize=[self frame].size;

	if(_trackingMode==kSideSpliterTracking){
		BOOL	sideIsRight=[self sideIsRight];
		float newSideWidth=[sideView frame].size.width;
		float maxSideWidth=[self frame].size.width-kHTTPVTopViewSeparatorThickness;

		if(!sideIsRight){
			newSideWidth+=dx;
			if(newSideWidth<kSideViewMinWidth){
				//dx-=newSideWidth;
				dx=0;
				newSideWidth=kSideViewMinWidth;
			}else if(newSideWidth > maxSideWidth){
				dx-=newSideWidth-maxSideWidth;
				newSideWidth=maxSideWidth;
			}
		}else{
			newSideWidth-=dx;
			if(newSideWidth<kSideViewMinWidth){
				//dx+=newSideWidth;
				dx=0;
				newSideWidth=kSideViewMinWidth;
			}else if(newSideWidth > maxSideWidth){
				dx+=newSideWidth-maxSideWidth;
				newSideWidth=maxSideWidth;
			}
		}

		_trackingStartPoint.x+=dx;
		
/*		if(_sideViewBestWidth>0){
			float	distance=abs(_sideViewBestWidth - newSideWidth);
			if(distance<4) newSideWidth=_sideViewBestWidth;
		}
*/
//		if(sideViewFrame.size.width<4)sideViewFrame.size.width=0;
		//_layoutInfo修正
		[_layoutInfo setObject:[NSNumber numberWithFloat:newSideWidth] forKey:@"sideViewtWidth"];
		float sideRatio=newSideWidth / selfSize.width;
		[_layoutInfo setObject:[NSNumber numberWithFloat:sideRatio] forKey:@"sideViewRatio"];

	}else if(_trackingMode==kMainSpliterTracking){
		if(dy<0){
			dy=abs(dy);
			if(bottomViewFrame.size.height-dy<=0){
				dy=bottomViewFrame.size.height;
				_trackingStartPoint.y-=dy;
			}else{
				_trackingStartPoint=currentPoint;
			}
			topViewFrame.size.height+=dy;
		}else{
			if(topViewFrame.size.height-dy<=0){
				dy=topViewFrame.size.height;
				_trackingStartPoint.y+=dy;
			}else{
				_trackingStartPoint=currentPoint;
			}
			topViewFrame.size.height-=dy;
		}
		//_layoutInfo修正
		[_layoutInfo setObject:[NSNumber numberWithFloat:topViewFrame.size.height] forKey:@"topViewStretch"];
		float topRatio=topViewFrame.size.height / selfSize.height;
		[_layoutInfo setObject:[NSNumber numberWithFloat:topRatio] forKey:@"topViewRatio"];
	}else if(_trackingMode==kMainSpliterTrackingVertical){
		float newSideWidth=[topView frame].size.width;
		// A hidden side view keeps its frame, so only subtract it while visible.
		float sideWidth=[self isSideViewVisible] ? [sideView frame].size.width : 0;
		float maxSideWidth=[self frame].size.width-sideWidth-kHTTPVTopViewSeparatorThickness;

		newSideWidth+=dx;
		if(newSideWidth<0){
			dx-=newSideWidth;
			newSideWidth=0;
		}else if(newSideWidth > maxSideWidth){
			dx-=newSideWidth-maxSideWidth;
			newSideWidth=maxSideWidth;
		}

		_trackingStartPoint.x+=dx;

/*		if(dx<0){
			dx=abs(dx);
			if(topViewFrame.size.width-dx<=0){
				dx=topViewFrame.size.width;
				_trackingStartPoint.x-=dx;
			}else{
				_trackingStartPoint=currentPoint;
			}
			bottomViewFrame.size.width+=dx;
		}else{
			if(bottomViewFrame.size.width-dx<=0){
				dx=bottomViewFrame.size.width;
				_trackingStartPoint.x+=dx;
			}else{
				_trackingStartPoint=currentPoint;
			}
			bottomViewFrame.size.width-=dx;
		}
*/


		//_layoutInfo修正
		[_layoutInfo setObject:[NSNumber numberWithFloat:newSideWidth] forKey:@"topViewStretch"];
		float topRatio=newSideWidth / maxSideWidth;
		[_layoutInfo setObject:[NSNumber numberWithFloat:topRatio] forKey:@"topViewRatio"];
	}

	[self _adjustLayout];
    [self setNeedsDisplay:YES];
}

- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[self _saveLayoutInfo];
}


- (BOOL)mouseDownCanMoveWindow
{
	return NO;
}

#pragma mark -

- (id)delegate
{
	return delegate;
}
- (void)setDelegate:(id)obj
{
	delegate=obj;
}

#pragma mark ---- subview ----


- (NSView*)sideView
{
	return sideView;
}

- (void)setSideView:(NSView*)view
{
	if(sideView != view){
		if([view superview]==self){
			if(topView != view && bottomView != view){
				sideView=view;
				[self _adjustLayout];
				[self setNeedsDisplay:YES];
			}
			return;
		}

		_oldView=[sideView retain];

		[sideView removeFromSuperview];
		//ここで willRemoveSubview:

		sideView=view;
		[self addSubview:view];
		
		if(_oldView && view){
			[view setFrame:[_oldView frame]];
			//[view setAutoresizingMask:[_oldView autoresizingMask]];
		}else{
			//[view setAutoresizingMask:[self _currentAutoresizingMaskForSideView]];
			[self _adjustLayout];
		}
		[self setNeedsDisplay:YES];
		[_oldView release];
		_oldView=nil;
	}
}

- (NSView*)topView
{
	return topView;
}

- (void)setTopView:(NSView*)view
{

	if(topView != view){
		if([view superview]==self){
			if(bottomView != view && sideView != view){
				topView=view;
				[self _adjustLayout];
				[self setNeedsDisplay:YES];
			}
			return;
		}
		_oldView=[topView retain];
		[topView removeFromSuperview];
		//ここで willRemoveSubview:

		topView=view;
		[self addSubview:view];
		
		if(_oldView && view){
			[view setFrame:[_oldView frame]];
			//[view setAutoresizingMask:[_oldView autoresizingMask]];
		}else{
			//[view setAutoresizingMask:[self _currentAutoresizingMaskForTopView]];
			[self _adjustLayout];
		}	
		[self setNeedsDisplay:YES];
		[_oldView release];
		_oldView=nil;
	}
}

- (NSView*)bottomView
{
	return bottomView;
}

- (void)setBottomView:(NSView*)view
{
	if(bottomView != view){
		if([view superview]==self){
			if(topView != view && sideView != view){
				bottomView=view;
				[self _adjustLayout];
				[self setNeedsDisplay:YES];
			}
			return;
		}
		
		_oldView=[bottomView retain];
		[bottomView removeFromSuperview];
		//ここで willRemoveSubview:

		bottomView=view;
		[self addSubview:view];
		
		if(_oldView && view){
			[view setFrame:[_oldView frame]];
			//[view setAutoresizingMask:[_oldView autoresizingMask]];
		}else{
			//[view setAutoresizingMask:[self _currentAutoresizingMaskForBottomView]];
			[self _adjustLayout];
		}
		[self setNeedsDisplay:YES];
		[_oldView release];
		_oldView=nil;
	}
}

#pragma mark -
#pragma mark ---- access ----

- (BOOL) sideViewAlternativeStyle
{
	if (_layoutInfo) {
		return [[_layoutInfo objectForKey:@"sideViewAlternativeStyle"] boolValue];
	}	
	return NO;
}

- (void) useSideViewAlternativeStyle: (BOOL) flag
{
	// [self setSideViewNeedsBorder: ! flag];

	BOOL currentFlag = [[_layoutInfo objectForKey:@"sideViewAlternativeStyle"] boolValue];
	if (currentFlag != flag) {
		[_layoutInfo setObject: [NSNumber numberWithBool:flag] 
						forKey: @"sideViewAlternativeStyle"];
		[self _adjustLayout];
		[self setNeedsDisplay:YES];
	}
}

- (BOOL)sideViewNeedsBorder
{
	if(_layoutInfo){
		return [[_layoutInfo objectForKey:@"sideViewNeedsBorder"]boolValue];
	}	
	return NO;
}

- (void)setSideViewNeedsBorder:(BOOL)flag
{
	BOOL currentFlag=[[_layoutInfo objectForKey:@"sideViewNeedsBorder"]boolValue];
	if(currentFlag != flag){
		[_layoutInfo setObject:[NSNumber numberWithBool:flag] forKey:@"sideViewNeedsBorder"];
		[self _adjustLayout];
		[self setNeedsDisplay:YES];
	}
}

- (BOOL)topViewNeedsBorder
{
	if(_layoutInfo){
		return [[_layoutInfo objectForKey:@"topViewNeedsBorder"]boolValue];
	}	
	return NO;
}

- (void)setTopViewNeedsBorder:(BOOL)flag
{
	BOOL currentFlag=[[_layoutInfo objectForKey:@"topViewNeedsBorder"]boolValue];
	if(currentFlag != flag){
		[_layoutInfo setObject:[NSNumber numberWithBool:flag] forKey:@"topViewNeedsBorder"];
		[self _adjustLayout];
		[self setNeedsDisplay:YES];
	}
}

- (BOOL)bottomViewNeedsBorder
{
	if(_layoutInfo){
		return [[_layoutInfo objectForKey:@"bottomViewNeedsBorder"]boolValue];
	}	
	return NO;
}

- (void)setBottomViewNeedsBorder:(BOOL)flag
{
	BOOL currentFlag=[[_layoutInfo objectForKey:@"bottomViewNeedsBorder"]boolValue];
	if(currentFlag != flag){
		[_layoutInfo setObject:[NSNumber numberWithBool:flag] forKey:@"bottomViewNeedsBorder"];
		[self _adjustLayout];
		[self setNeedsDisplay:YES];
	}
}

#pragma mark -
- (NSString *)autosaveName
{
	return _autosaveName;
}

- (void)setAutosaveName:(NSString *)name
{
	if(name != _autosaveName){
		[_autosaveName autorelease];
		_autosaveName=[name retain];
		[self _loadLayoutInfo];
		
		[self _adjustLayout];
		[self setNeedsDisplay:YES];
	}
}

- (NSDictionary*)layoutInfo
{
	return _layoutInfo;
}

- (void)setLayoutInfo:(NSDictionary*)pref
{
	if(_layoutInfo != pref){
		[_layoutInfo autorelease];
		_layoutInfo=[pref retain];
	}
}


#pragma mark -

- (BOOL)sideIsRight
{
	if(_layoutInfo){
		return [[_layoutInfo objectForKey:@"sideIsRight"]boolValue];
	}
	
	return NO;
}

- (void)setSideIsRight:(BOOL)flag
{
	BOOL sideIsRight=[[_layoutInfo objectForKey:@"sideIsRight"]boolValue];
	if(sideIsRight != flag){
		if([delegate respondsToSelector:@selector(threePaneSplitViewWillChangeSideViewPosition:)]){
			[delegate threePaneSplitViewWillChangeSideViewPosition:self];
		}
		
		[_layoutInfo setObject:[NSNumber numberWithBool:flag] forKey:@"sideIsRight"];
		[self _adjustLayout];
		[[self superview] setNeedsDisplay:YES];
	}
}

- (BOOL)isVertical
{
	if(_layoutInfo){
		return [[_layoutInfo objectForKey:@"isVertical"]boolValue];
	}
	
	return NO;
}

- (void)setVertical:(BOOL)flag
{
	if([self isVertical] != flag){
		if([delegate respondsToSelector:@selector(threePaneSplitViewWillChangeVartical:)]){
			[delegate threePaneSplitViewWillChangeVartical:self];
		}

		[_layoutInfo setObject:[NSNumber numberWithBool:flag] forKey:@"isVertical"];
		[self _adjustLayout];
		[self setNeedsDisplay:YES];
	
	}

}

- (BOOL) isSideViewVisible
{
	return sideView != nil && ! [sideView isHidden];
}

// Hides or shows the side view. The side view keeps its width while hidden,
// so it comes back at the same size.
- (void) showSideView: (BOOL) flag
{
	if (! sideView || [self isSideViewVisible] == flag) {
		return;
	}
	[sideView setHidden: ! flag];

    [self _adjustLayout];
    [self setNeedsDisplay: YES];
}

- (void) showBottomView: (BOOL) flag
{
    if (flag) {
        [_layoutInfo setObject: [NSNumber numberWithFloat: 0] 
                        forKey: @"topViewStretch"];
        [_layoutInfo setObject: [NSNumber numberWithFloat: 0] 
                        forKey: @"topViewRatio"];
    } else {
        [_layoutInfo setObject: [NSNumber numberWithFloat: [self frame].size.height] 
                        forKey: @"topViewStretch"];
        [_layoutInfo setObject: [NSNumber numberWithFloat: 1.0] 
                        forKey: @"topViewRatio"];
    }
    
    [self _adjustLayout];
    [self setNeedsDisplay: YES];
}


#pragma mark -

- (IBAction)toggleVertical:(id)sender
{
	BOOL isVertical=[[_layoutInfo objectForKey:@"isVertical"]boolValue];
	[self setVertical:!isVertical];
}

- (IBAction)toggleSideViewPosition:(id)sender
{
	BOOL sideIsRight=[[_layoutInfo objectForKey:@"sideIsRight"]boolValue];
	[self setSideIsRight:!sideIsRight];
}

- (IBAction) toggleSideView: (id) sender
{
    [self showSideView: ! [self isSideViewVisible]];
}

- (IBAction) toggleBottomView: (id) sender
{
    if ([[_layoutInfo objectForKey: @"topViewStretch"] floatValue] == 0.0) {
        float stretch;
        if ([self isVertical]) {
            stretch = [self frame].size.width;
        } else {
            stretch = [self frame].size.height;
        }
        [_layoutInfo setObject: [NSNumber numberWithFloat: stretch] 
                        forKey: @"topViewStretch"];
        [_layoutInfo setObject: [NSNumber numberWithFloat: 1.0] 
                        forKey: @"topViewRatio"];
    } else {
        [_layoutInfo setObject: [NSNumber numberWithFloat: 0] 
                        forKey: @"topViewStretch"];
        [_layoutInfo setObject: [NSNumber numberWithFloat: 0] 
                        forKey: @"topViewRatio"];
    }
    
    [self _adjustLayout];
    [self setNeedsDisplay: YES];
}

#pragma mark -
#pragma mark ---- private ----

//デフォルトの設定
- (void)_setUpDefaultLayoutInfo
{
	if(_layoutInfo==nil){
		_layoutInfo=[[NSMutableDictionary alloc]initWithObjectsAndKeys:
			[NSNumber numberWithInt:kHTTPVPrefVersion], @"_version",
			[NSNumber numberWithFloat:kHTTPVSideViewDefaultRatio], @"sideViewRatio",
			[NSNumber numberWithFloat:0], @"sideViewtWidth",
			[NSNumber numberWithFloat:kHTTPVTopViewDefaultRatio],@"topViewRatio",
			[NSNumber numberWithFloat:0], @"topViewStretch",
			[NSNumber numberWithBool:NO], @"sideIsRight",
			[NSNumber numberWithBool:NO], @"isVertical",
			[NSNumber numberWithBool:NO], @"sideViewNeedsBorder",
			[NSNumber numberWithBool:NO], @"topViewNeedsBorder",
			[NSNumber numberWithBool:NO], @"bottomViewNeedsBorder",
		nil];
	}
}
- (NSString *)autosaveNamePrefix
{
	return [[self className]stringByAppendingString:@"_"];
}

- (void)_loadLayoutInfo
{
	if(_layoutInfo==nil){
		[self _setUpDefaultLayoutInfo];
	}
	if(_autosaveName){
		NSString*	prefKey=[[self autosaveNamePrefix]stringByAppendingString:_autosaveName];
		NSDictionary* prefDict=[[NSUserDefaults standardUserDefaults]dictionaryForKey:prefKey];
		if(prefDict && [[prefDict objectForKey:@"_version"]floatValue]==kHTTPVPrefVersion){
			[_layoutInfo setDictionary:prefDict];
		}
	}
}

- (void)_saveLayoutInfo
{
	if(_layoutInfo && _autosaveName){
		NSString*	prefKey=[[self autosaveNamePrefix]stringByAppendingString:_autosaveName];
		[[NSUserDefaults standardUserDefaults]setObject:_layoutInfo forKey:prefKey];
	}
}

/*
//廃止
- (unsigned int)_currentAutoresizingMaskForSideView
{
	unsigned int mask=NSViewHeightSizable;
	BOOL sideIsRight=[[_layoutInfo objectForKey:@"sideIsRight"]boolValue];
	if(sideIsRight){
		mask|=NSViewMinXMargin;
	}else{
		mask|=NSViewMaxXMargin;
	}
	return mask;
}

- (unsigned int)_currentAutoresizingMaskForTopView
{
	//return 0;
	if([self isVertical]){
	}else{
		return NSViewWidthSizable|NSViewHeightSizable;

		if(_sideIsRight){
			return NSViewWidthSizable|NSViewMaxXMargin;
		}else{
			return NSViewWidthSizable|NSViewMinXMargin;
		}
	}
	return 0;
}

- (unsigned int)_currentAutoresizingMaskForBottomView
{
	//return 0;
	if([self isVertical]){
	}else{
		return NSViewWidthSizable|NSViewHeightSizable;
		if(_sideIsRight){
			return NSViewWidthSizable|NSViewMaxXMargin;
		}else{
			return NSViewWidthSizable|NSViewMinXMargin;
		}
	}
	return 0;
}
*/

//リサイズ メイン
- (void)_adjustLayout
{
	NSSize frameSize=[self frame].size;
	NSRect sideFrame=NSZeroRect;
	NSRect mainFrame=NSZeroRect;
	NSRect bottomFrame=NSZeroRect;
	float sideViewRatio=kHTTPVSideViewDefaultRatio;
	float sideViewtWidth=0;
	float topViewStretch=0;
	float topViewRatio=kHTTPVTopViewDefaultRatio;
	BOOL sideIsRight=NO;
	BOOL	topViewNeedsBorder=[self topViewNeedsBorder];
	BOOL	bottomViewNeedsBorder=[self bottomViewNeedsBorder];
	
	if(_layoutInfo){
		sideViewRatio=[[_layoutInfo objectForKey:@"sideViewRatio"]floatValue];
		sideViewtWidth=[[_layoutInfo objectForKey:@"sideViewtWidth"]floatValue];
		topViewRatio=[[_layoutInfo objectForKey:@"topViewRatio"]floatValue];
		sideIsRight=[[_layoutInfo objectForKey:@"sideIsRight"]boolValue];
		topViewStretch=[[_layoutInfo objectForKey:@"topViewStretch"]floatValue];
	}
	if([self isSideViewVisible]){
		float thickness;
        
        if ([[_layoutInfo objectForKey:@"sideViewAlternativeStyle"] boolValue]) {
            thickness = 2;
        } else {
            if ([[_layoutInfo objectForKey:@"sideViewNeedsBorder"] boolValue]) {
                thickness = kHTTPVTopViewSeparatorThickness;
            } else {
                thickness = 0.0;
            }
        }
            
		// FIXME
		// sideFrame.size.height=frameSize.height;
		sideFrame.size.height = frameSize.height;
		if(sideViewtWidth>0){
			sideFrame.size.width=sideViewtWidth;
		}else{
			sideFrame.size.width=(int)(frameSize.width * sideViewRatio);
			[_layoutInfo setObject:[NSNumber numberWithFloat:sideFrame.size.width] forKey:@"sideViewtWidth"];
		}
		if(sideFrame.size.width<kSideViewMinWidth){
			sideFrame.size.width=kSideViewMinWidth;
			sideViewtWidth=kSideViewMinWidth;
		}
		//はみださないように
		float	mainThickness=0;
		if([self isVertical])mainThickness=kHTTPVTopViewSeparatorThickness;
		if(sideViewtWidth > frameSize.width - thickness - mainThickness){
			sideFrame.size.width = frameSize.width - thickness - mainThickness;
		}
		
		mainFrame.size.height=frameSize.height;
		mainFrame.size.width=frameSize.width - sideFrame.size.width - thickness;
		
		if(sideIsRight){
			sideFrame.origin.x= frameSize.width - sideFrame.size.width;
			_sideSpliterRect.origin.x=sideFrame.origin.x - thickness;
		}else{
			mainFrame.origin.x=sideFrame.size.width + thickness;
			_sideSpliterRect.origin.x=sideFrame.size.width;
		}
		//_sideSpliterRect
		if ([[_layoutInfo objectForKey:@"sideViewAlternativeStyle"] boolValue]) {
			sideFrame.origin.y = [NSScroller scrollerWidth];
			sideFrame.size.height -= sideFrame.origin.y;

			_sideSpliterRect.size.width  = [NSScroller scrollerWidth];
			_sideSpliterRect.size.height = [NSScroller scrollerWidth];
			_sideSpliterRect.origin.x = sideFrame.size.width - _sideSpliterRect.size.width;
			_sideSpliterRect.origin.y = 0;
		} else {
			_sideSpliterRect.origin.y=0;
			_sideSpliterRect.size.height=frameSize.height;
			_sideSpliterRect.size.width=thickness;
		}
	}else{
		mainFrame.size=frameSize;
		_sideSpliterRect=NSZeroRect;
	}

		
	bottomFrame=mainFrame;
	if(bottomView && topView){
		if([self isVertical]){
			if(topViewStretch>0){
				mainFrame.size.width=topViewStretch;
			}else{
				mainFrame.size.width =(int)(mainFrame.size.width * topViewRatio);
				[_layoutInfo setObject:[NSNumber numberWithFloat:mainFrame.size.width] forKey:@"topViewStretch"];
			}
			//はみださないように
			if(mainFrame.size.width > bottomFrame.size.width - kHTTPVTopViewSeparatorThickness){
				mainFrame.size.width = bottomFrame.size.width - kHTTPVTopViewSeparatorThickness;
			}
			bottomFrame.size.width = bottomFrame.size.width - mainFrame.size.width - kHTTPVTopViewSeparatorThickness;
			bottomFrame.origin.x += mainFrame.size.width + kHTTPVTopViewSeparatorThickness;
			//枠ずらす
			/*
			if(!topViewNeedsBorder){
				mainFrame.size.width+=1;
				if(!sideIsRight){
					mainFrame.origin.x-=1;
				}
			}
			if(!bottomViewNeedsBorder){
				bottomFrame.size.width+=1;
				if(!sideIsRight){
					bottomFrame.origin.x-=1;
				}
			}*/
			//_mainSpliterRect
			_mainSpliterRect.size.width=kHTTPVTopViewSeparatorThickness;
			_mainSpliterRect.size.height=mainFrame.size.height;
			_mainSpliterRect.origin.y=mainFrame.origin.y;
			_mainSpliterRect.origin.x=mainFrame.origin.x+mainFrame.size.width;
		}else{
			if(topViewStretch>0){
				mainFrame.size.height=topViewStretch;
			}else{
				mainFrame.size.height =(int)(mainFrame.size.height * topViewRatio);
				[_layoutInfo setObject:[NSNumber numberWithFloat:mainFrame.size.height] forKey:@"topViewStretch"];
			}
			//はみださないように
			if(mainFrame.size.height > frameSize.height - kHTTPVTopViewSeparatorThickness){
				mainFrame.size.height = frameSize.height - kHTTPVTopViewSeparatorThickness;
			}

			bottomFrame.size.height = frameSize.height - mainFrame.size.height - kHTTPVTopViewSeparatorThickness;
			mainFrame.origin.y = bottomFrame.size.height + kHTTPVTopViewSeparatorThickness;
			//枠ずらす
			if(!topViewNeedsBorder){
				mainFrame.size.width+=1;
				if(!sideIsRight){
					mainFrame.origin.x-=1;
				}
			}
			if(!bottomViewNeedsBorder){
				bottomFrame.size.width+=1;
				if(!sideIsRight){
					bottomFrame.origin.x-=1;
				}
			}

			//_mainSpliterRect
			_mainSpliterRect.size.height=kHTTPVTopViewSeparatorThickness;
			_mainSpliterRect.size.width=mainFrame.size.width;
			_mainSpliterRect.origin.x=mainFrame.origin.x;
			_mainSpliterRect.origin.y=bottomFrame.size.height;
			if([self isSideViewVisible]){
				_mainSpliterRect.size.width+=1;
				if(!sideIsRight){
					_mainSpliterRect.origin.x-=1;
				}
			}
		}
	}else{
		_mainSpliterRect=NSZeroRect;
	}

	// Keep the hidden side view's frame (and so its outline columns) intact.
	if([self isSideViewVisible]){
		[sideView setFrame:sideFrame];
	}
	[topView setFrame:mainFrame];
	[bottomView setFrame:bottomFrame];
}

@end

@implementation HTThreePaneSplitView (SpliterUISupport)

// resource 使うと組み込み面倒なのでこんな手段で、、、
// バイト列は PNG です

+ (NSImage*)verticalPatternImage
{
	static NSImage* _verticalPatternImage=nil;
	if(_verticalPatternImage==nil){
		UInt8 bytes[]={
		0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
		0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x02, 0x08, 0x02, 0x00, 0x00, 0x00, 0xee, 0x03, 0xda,
		0x87, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73, 0x00, 0x00, 0x0b, 0x13, 0x00, 0x00, 0x0b,
		0x13, 0x01, 0x00, 0x9a, 0x9c, 0x18, 0x00, 0x00, 0x00, 0x23, 0x49, 0x44, 0x41, 0x54, 0x08, 0x99,
		0x63, 0x5c, 0xba, 0x74, 0x69, 0x78, 0x78, 0xf8, 0xbf, 0x7f, 0xff, 0xfe, 0xfe, 0xfd, 0xfb, 0xe7,
		0xcf, 0x9f, 0xdf, 0x48, 0xe0, 0xd8, 0xb1, 0x63, 0x4c, 0x0c, 0x78, 0x01, 0x00, 0x9d, 0xdc, 0x19,
		0xf3, 0xdb, 0x7c, 0x7c, 0x73, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60,
		0x82};

		NSData* data=[NSData dataWithBytes:bytes length:sizeof(bytes)];
		_verticalPatternImage=[[NSImage alloc]initWithData:data];
	}
	return _verticalPatternImage;
}

+ (NSImage*)horizontalPatternImage
{
	static NSImage* _horizontalPatternImage=nil;
	if(_horizontalPatternImage==nil){
		UInt8 bytes[]={
		0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
		0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x0a, 0x08, 0x02, 0x00, 0x00, 0x00, 0x11, 0x87, 0x18,
		0x1e, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73, 0x00, 0x00, 0x0b, 0x13, 0x00, 0x00, 0x0b,
		0x13, 0x01, 0x00, 0x9a, 0x9c, 0x18, 0x00, 0x00, 0x00, 0x2e, 0x49, 0x44, 0x41, 0x54, 0x08, 0x99,
		0x75, 0xc8, 0xb1, 0x0d, 0xc0, 0x30, 0x08, 0x00, 0x30, 0x47, 0xe2, 0xff, 0x2f, 0x78, 0x85, 0xa7,
		0x08, 0x28, 0x4b, 0xd7, 0x4e, 0x96, 0x7c, 0x32, 0x13, 0xe7, 0xde, 0x8b, 0xd8, 0x5d, 0xc4, 0xcc,
		0x20, 0xbe, 0xec, 0xee, 0x5f, 0xaa, 0x0a, 0x0f, 0xf3, 0x11, 0x1c, 0x01, 0xc1, 0x96, 0x2b, 0xbb,
		0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82 };

		NSData* data=[NSData dataWithBytes:bytes length:sizeof(bytes)];
		_horizontalPatternImage=[[NSImage alloc]initWithData:data];
	}
	return _horizontalPatternImage;
}

+ (NSImage*)dimpleImage
{
	static NSImage* _dimpleImage=nil;
	if(_dimpleImage==nil){
		UInt8 bytes[]={
		0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
		0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, 0x08, 0x02, 0x00, 0x00, 0x00, 0x26, 0x93, 0x09,
		0x29, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73, 0x00, 0x00, 0x0b, 0x13, 0x00, 0x00, 0x0b,
		0x13, 0x01, 0x00, 0x9a, 0x9c, 0x18, 0x00, 0x00, 0x00, 0x39, 0x49, 0x44, 0x41, 0x54, 0x08, 0x99,
		0x05, 0xc1, 0xb1, 0x09, 0x00, 0x30, 0x08, 0x00, 0xc1, 0x0f, 0xa4, 0xb2, 0xb6, 0x93, 0x4c, 0xe1,
		0xfe, 0x23, 0x88, 0x85, 0xe0, 0x06, 0xae, 0x60, 0x9d, 0xbb, 0x93, 0x99, 0x11, 0x01, 0xb8, 0xfb,
		0xed, 0xee, 0xf7, 0x1e, 0xd0, 0xdd, 0x57, 0x44, 0x54, 0x15, 0xd8, 0xdd, 0x53, 0x55, 0x33, 0x03,
		0x98, 0xd9, 0x07, 0x17, 0x22, 0x13, 0x88, 0xd0, 0x51, 0x26, 0xe1, 0x00, 0x00, 0x00, 0x00, 0x49,
		0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82 };

		NSData* data=[NSData dataWithBytes:bytes length:sizeof(bytes)];
		_dimpleImage=[[NSImage alloc]initWithData:data];
	}
	return _dimpleImage;
}

- (void)drawSpliterWithFrame:(NSRect)cellFrame firstViewNeedsBorder:(BOOL)fBorder secondViewNeedsBorder:(BOOL)sBorder;
{
	
	NSPoint dimplePoint=cellFrame.origin;
	NSImage* image=nil;
	NSCompositingOperation dimpleOp=NSCompositeCopy;
	
#if 0
	if(([[self window]styleMask] & NSTexturedBackgroundWindowMask) == 0){
		//Aqua
		NSRect fromRect;
		if(cellFrame.size.width > cellFrame.size.height){
			//yoko naga
			image=[HTThreePaneSplitView horizontalPatternImage];
			fromRect.size=[image size];
			fromRect.origin.x=0;
			fromRect.origin.y=0;
			if(!sBorder){
				fromRect.size.height--;
				fromRect.origin.y=1;
			}
			
			if(!fBorder){
				fromRect.size.height--;
			}
		}else{
			//tate naga
			image=[HTThreePaneSplitView verticalPatternImage];
			fromRect.size=[image size];
			fromRect.origin.x=0;
			fromRect.origin.y=0;
			
			if(!fBorder){
				fromRect.size.width--;
				fromRect.origin.x=1;
			}
			if(!sBorder){
				fromRect.size.width--;
			}
		}
		[image drawInRect:cellFrame fromRect:fromRect operation:NSCompositeCopy fraction:1.0];
	}else{
		//Metal
		//dimple を暗くする
		dimpleOp=NSCompositePlusDarker;
		
		//枠線 あまり奇麗じゃない
		float stagger=0;
		float x=cellFrame.origin.x;
		float y=cellFrame.origin.y;
		[[NSColor controlShadowColor]set];
		//[[NSColor blackColor]set];
		if(cellFrame.size.width > cellFrame.size.height){
			//yoko naga
			float line=y+cellFrame.size.height-stagger;
			if(fBorder) [NSBezierPath strokeLineFromPoint:NSMakePoint(x,line)
							toPoint:NSMakePoint(x+cellFrame.size.width,line)];
			if(sBorder) [NSBezierPath strokeLineFromPoint:NSMakePoint(x,y+stagger)
							toPoint:NSMakePoint(x+cellFrame.size.width,y+stagger)];
		}else{
			//tate naga
			float line=x+cellFrame.size.width-stagger;
			if(fBorder) [NSBezierPath strokeLineFromPoint:NSMakePoint(x+stagger,y)
							toPoint:NSMakePoint(x+stagger,y+cellFrame.size.height)];
			if(sBorder) [NSBezierPath strokeLineFromPoint:NSMakePoint(line,y)
							toPoint:NSMakePoint(line,y+cellFrame.size.height)];
		}
	}
#endif
	
	if(cellFrame.size.width>=6 && cellFrame.size.height >=6){
		image=[HTThreePaneSplitView dimpleImage];
		dimplePoint.y+=(cellFrame.size.height-4)/2;
		dimplePoint.x+=(cellFrame.size.width-4)/2;
		[image compositeToPoint:dimplePoint operation:dimpleOp];
	}

}

@end
