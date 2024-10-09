//
//  STSummerTime.h
//  RunmefitSDK
//
//  Created by 星迈 on 2024/5/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface STSummerTime : NSObject

@property(nonatomic,assign) NSInteger city_id;
@property(nonatomic,assign) NSInteger start_month;
@property(nonatomic,assign) NSInteger start_week;
@property(nonatomic,assign) NSInteger end_month;
@property(nonatomic,assign) NSInteger end_week;
@property(nonatomic,assign) NSInteger time_offset;

@end

NS_ASSUME_NONNULL_END
