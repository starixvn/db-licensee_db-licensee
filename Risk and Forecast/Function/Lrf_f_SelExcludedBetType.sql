/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DB042-bodb02" executers="" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[Lrf_f_SelExcludedBetType]()
RETURNS TABLE
/*
	Creator: Louis
	Date: 2020-10-08
	Task: Get Excluded Bet Types from Reports
	DB: DBEXT-bodb02
	Revision:
		- 20201008@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20210203@Louis: Saba Red Envelope [RedmineID: #149923]
*/

RETURN
	SELECT 0 AS ProductId, 999 AS BetType				--- Licensee Spread Setting
	UNION ALL 
	SELECT 32, 4297 									--- Pragmatic Play - Promotion Prize
	UNION ALL 
	SELECT 32, 4298 									--- Pragmatic Play - Promotion Prize
	UNION ALL 
	SELECT 32, 4299										--- Pragmatic Play - Promotion Prize
	UNION ALL 
	SELECT 32, 4300	 									--- Pragmatic Play - Promotion Prize
	UNION ALL 
	SELECT 37, 17000									--- Saba Loyalty
	UNION ALL 
	SELECT 37, 17003									--- Saba Loyalty
	UNION ALL 
	SELECT 37, 17004									--- Saba Red Envelope
	UNION ALL 
	SELECT 39, 3007										--- SA Gaming Tip ticket
	UNION ALL 
	SELECT 34, 1906										--- Arcadia Gaming Bonus
GO