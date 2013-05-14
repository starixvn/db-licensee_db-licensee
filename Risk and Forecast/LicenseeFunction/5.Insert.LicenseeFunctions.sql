/*
BA: 12Bet, asiabet88, alog, TLC, DELA
Racing: 12Bet, alog, asiabet88, mansion88, MayFair, SunGame, TLC, ZZun88, spondemo
_TotalBets/Horseracing.aspx -- 22
_Reports/Commission/HRCommission.aspx  -- 34
_Reports/Racing/RacingWinLoss.aspx-- 35
Number Game: 12Bet, alog
_TotalBets/NumberGame.aspx -- 23

==> Only 12Bet have persmission on all functions

*/

-- 

USE [bodb_Licensee]
GO


TRUNCATE TABLE [LicenseeFunctions]

GO

--1		12Bet has full permission
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 1, FunctionId FROM [Functions]

-- 2	asiabet88 does does not has permission on NumberGame. FunctionId = 23
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 2, FunctionId FROM [Functions]
WHERE FunctionId <> 23

-- 3	mansion88 does not has permission on NumberGame. FunctionId = 23
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 3, FunctionId FROM [Functions]
WHERE FunctionId <> 23

-- 4	alog has full permission
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 4, FunctionId FROM [Functions]

-- 5	spondemo does not has permission on NumberGame. FunctionId = 23
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 5, FunctionId FROM [Functions]
WHERE FunctionId <> 23

-- 6	TLC does not has permission on NumberGame. FunctionId = 23
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 6, FunctionId FROM [Functions]
WHERE FunctionId <> 23

-- 7	DELA does not has permission on NumberGame && Racing. FunctionId = 22, 23, 34, 35
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 7, FunctionId FROM [Functions]
WHERE FunctionId NOT IN (22, 23, 34, 35)

-- 8	SunGame does not has permission on NumberGame. FunctionId = 23
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 8, FunctionId FROM [Functions]
WHERE FunctionId <> 23

-- 9	MayFair does not has permission on NumberGame. FunctionId = 23
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 9, FunctionId FROM [Functions]
WHERE FunctionId <> 23

-- 10	Zzun88 does not has permission on NumberGame. FunctionId = 23
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 10, FunctionId FROM [Functions]
WHERE FunctionId <> 23

-- 11	Bezbet does not has permission on NumberGame && Racing. FunctionId = 22, 23, 34, 35
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 11, FunctionId FROM [Functions]
WHERE FunctionId NOT IN (22, 23, 34, 35)

-- 12	HAIFA does not has permission on NumberGame && Racing. FunctionId = 22, 23, 34, 35
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 12, FunctionId FROM [Functions]
WHERE FunctionId NOT IN (22, 23, 34, 35)

-- 14	Bodog does not has permission on NumberGame && Racing. FunctionId = 22, 23, 34, 35
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 14, FunctionId FROM [Functions]
WHERE FunctionId NOT IN (22, 23, 34, 35)

-- 15	Vwin does not has permission on NumberGame && Racing. FunctionId = 22, 23, 34, 35
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 15, FunctionId FROM [Functions]
WHERE FunctionId NOT IN (22, 23, 34, 35)

-- 16	SG8 does not has permission on NumberGame && Racing. FunctionId = 22, 23, 34, 35
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 16, FunctionId FROM [Functions]
WHERE FunctionId NOT IN (22, 23, 34, 35)

-- 17	Tycoon does not has permission on NumberGame && Racing. FunctionId = 22, 23, 34, 35
INSERT INTO [LicenseeFunctions](LicenseeId, FunctionId)
SELECT 17, FunctionId FROM [Functions]
WHERE FunctionId NOT IN (22, 23, 34, 35)