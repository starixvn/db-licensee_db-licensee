USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BATimeCheck]    Script Date: 1/3/2014 10:15:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Lrf_BATimeCheck    Script Date: 5/8/2013 3:14:49 AM ******/
/****** Object:  Stored Procedure dbo.Lrf_BATimeCheck    Script Date: 5/6/2013 1:42:14 PM ******/
ALTER PROCEDURE [dbo].[Lrf_BATimeCheck]   
	@IsAllow BIT = 0 OUTPUT,
	@LicenseeID INT,
	@CurrencyID	INT=0,
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS  
/*
	Created by: [20110510@Henry]
	Task: Check whether current date, current time can update BA or not
	DB: DB052.bodb_Licensee
	Param's Explanation:
	
	
	Revisions:
	- 20110908@Henry: Remove Thursday and Friday, just allow Monday only
	- 20110913@Henry: Restriction setting for each licensee separately (full allow to spondemo)
	- 20110926@Henry: Full allow for Dela
	- 20111213@Henry: Full allow for Zzun88
	- 20120831@Henry: Zzun88 only allowed to turn-on BA on monday
	- 20130405@Jim: support multiple language
	- 20140102@Jim: Full allow for Asiabet88 
*/
SET NOCOUNT ON
SELECT @Langkey=ltrim(rtrim(@Langkey))
IF (@LicenseeID IN (5,7) OR (@CurrencyID IN (3,6) AND @LicenseeID=2))  --Spondemo , Dela OR (asiabet88 and currency is EUR,USD)
BEGIN
	SELECT @IsAllow = 1
	RETURN
END

ELSE IF @LicenseeID=4 --alog
BEGIN
	--monday, 1PM to 5PM
	IF datepart(weekday, getdate()) = 2 AND (datepart(hour, getdate()) between 1 AND 5)
		SELECT @IsAllow=1
	ELSE
	BEGIN
		SELECT @IsAllow=0	
		
		SELECT @ErrMsg = CASE @Langkey 
								WHEN 'en-US' THEN 'BA status can only be changed on Monday from 1PM to 5PM (GMT+8)'
								ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200005,@Langkey)
							END, @ErrCode = 100
			RETURN
	END
END
ELSE
BEGIN
	--monday, 1PM to 5PM
	IF datepart(weekday, getdate()) = 2 AND (datepart(hour, getdate()) between 1 AND 5)
		SELECT @IsAllow=1
	ELSE
	BEGIN
		SELECT @IsAllow=0	
		
		SELECT @ErrMsg = CASE @Langkey
								WHEN 'en-US' THEN 'BA status can only be changed on Monday from 1PM to 5PM (GMT+8)'
								ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200005,@Langkey)
							END, @ErrCode = 101
			RETURN
	END
END
GO
GRANT EXECUTE ON [dbo].[Lrf_BATimeCheck] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_BATimeCheck] TO [Dot_Member] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BATimeCheck] TO [vnteam] AS [dbo]