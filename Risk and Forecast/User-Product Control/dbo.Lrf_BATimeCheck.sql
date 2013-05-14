ALTER PROCEDURE [dbo].[Lrf_BATimeCheck]   
	@IsAllow BIT = 0 OUTPUT,
	@LicenseeID INT,
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
*/
SET NOCOUNT ON
SELECT @Langkey=ltrim(rtrim(@Langkey))
IF @LicenseeID=5 OR @LicenseeID = 7  --Spondemo and Dela
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
GRANT EXECUTE ON [dbo].[Lrf_BATimeCheck] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BATimeCheck] TO [vnteam] 	
 