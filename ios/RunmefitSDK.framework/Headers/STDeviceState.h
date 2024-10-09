//
//  STDeviceState.h
//  RunmefitSDK
//
//  Created by 星迈 on 2022/8/8.
//  🍎设备状态

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    /// 24小时制（默认）
    STlTimeModeHour24 = 0x00,
    /// 12小时制
    STlTimeModeHour12 = 0x01,
    
}STlTimeMode;


typedef enum : NSUInteger {
    /// 公制（默认）
    STUnitMetric = 0x00,
    /// 英制
    STUnitImperial = 0x01,
    
}STUnit;


typedef enum : NSUInteger {
    /// 摄氏（默认）
    STlTemperatureUnitCelsius = 0x00,
    /// 华氏
    STlTemperatureUnitFahrenheit = 0x01,
    
}STlTemperatureUnit;


typedef enum : NSUInteger {
    /// 🇨🇳中文
    STlLanguageChinese = 0x00,
    /// 🇨🇳繁体中文
    STlLanguageTd_chinese = 0x01,
    /// 🇬🇧英语
    STlLanguageEnglish = 0x02,
    /// 🇷🇺俄语
    STlLanguageRussian = 0x03,
    /// 🇫🇷法语
    STlLanguageFrench = 0x04,
    /// 🇪🇸西班牙语
    STlLanguageSpanish = 0x05,
    /// 🇩🇪德语
    STlLanguageGerman = 0x06,
    /// 🇯🇵日语
    STlLanguageJapan = 0x07,
    /// 🇮🇹意大利语
    STlLanguageItaly = 0x08,
    /// 🇰🇷韩语
    STlLanguageKorean = 0x09,
    /// 🇳🇱荷兰语
    STlLanguageNetherlands = 0x0A,
    /// 🇹🇭泰语
    STlLanguageThai = 0x0B,
    
    /// 🇻🇳越南
    STlLanguageVietnamese = 0x0C,
    /// 🇲🇾马来西亚
    STlLanguageMalaysia = 0x0D,
    /// 🇮🇩印尼
    STlLanguageIndonesia = 0x0E,
    /// 🇵🇹葡萄牙语
    STlLanguagePortuguese = 0x0F,
    /// 🇷🇴罗马尼亚语
    STlLanguageRomania = 0x10,
    /// 🇵🇱波兰语
    STlLanguagePoland = 0x11,
    /// 🇹🇷土耳其语
    STlLanguageTurkish = 0x12,
    /// 🇲🇳蒙古语
    STlLanguageMongolian = 0x13,
    /// 🇮🇳印度
    STlLanguageHindi = 0x14,
    /// 🇸🇦阿拉伯语
    //STlLanguageArabic = 0x15,
    /// 🇮🇱希伯来语
    //STlLanguageHebrew = 0x16,
    
}STlLanguage;


NS_ASSUME_NONNULL_BEGIN

@interface STDeviceState : NSObject

/// 时间制式
@property(nonatomic,assign) STlTimeMode timeMode;
/// 单位
@property(nonatomic,assign) STUnit unit;
/// 温度单位
@property (nonatomic,assign) STlTemperatureUnit temperatureUnit;
/// 语言选择
@property(nonatomic,assign) STlLanguage language;
/// 亮屏时长(秒为单位)
@property(nonatomic,assign) NSInteger brightDuration;
/// 屏幕亮度(百分比)
@property(nonatomic,assign) NSInteger brightness;
/// 翻腕亮屏(开关)
@property(nonatomic,assign) BOOL trunWrist;

@end

NS_ASSUME_NONNULL_END
