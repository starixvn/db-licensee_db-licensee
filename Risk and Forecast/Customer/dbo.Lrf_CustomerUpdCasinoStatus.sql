set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER   PROCEDURE [dbo].[Lrf_CustomerUpdCasinoStatus]
	@userID INT,
	@custid INT,
	@SportID INT,
	@Status BIT ,
	@Language VARCHAR(2) = 'E',
	@IP VARCHAR(40)='',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
/*
Created: 20131021@Jim
Task : LRF - Allow users to enable/ disable Casino games for specific players
DB: DB052.bodb02
Original: 
Revisions:
    
Param's Explanation:

*/
BEGIN
	DECLARE @UserName VARCHAR(100)
	SELECT @UserName=UserName
	FROM DBLIC.bodb_licensee.dbo.Users WITH (NOLOCK)
	WHERE UserID=@userID
	IF @SportID=162 -- Live Casino 
		BEGIN 
				IF EXISTS (SELECT TOP 1 1 FROM dbo.CustInfo WITH (NOLOCK) WHERE custid=@custid )
					BEGIN 
						UPDATE dbo.CustInfo WITH (ROWLOCK,UPDLOCK)
						SET 	disableLiveCasino=@Status 
						WHERE custid=@custid
						
						  SELECT @ErrMsg = @UserName + ': '+
								CASE @Language 
									WHEN 'E' THEN 'Update process is successful !'
									WHEN 'CS' THEN N'??????? !'
									WHEN 'CT' THEN N'??????? !'
									WHEN 'TH' THEN N'????????????????????????????????????????????!'
									WHEN 'J' THEN N'????????????'
									WHEN 'KO' THEN N'????? ??????.'
									ELSE N'Update process is successful !'
								END
								RETURN	
					END
			 ELSE 
				BEGIN 
					 SELECT @ErrMsg = @UserName + ': '+
								CASE @Language 
									WHEN 'E' THEN 'This customer has never played Live Casino !'
									WHEN 'CS' THEN N'??????? !'
									WHEN 'CT' THEN N'??????? !'
									WHEN 'TH' THEN N'????????????????????????????????????????????!'
									WHEN 'J' THEN N'????????????'
									WHEN 'KO' THEN N'????? ??????.'
									ELSE N'This customer has never played Live Casino!'
								END, @ErrCode = 115
								RETURN	
				END	
		END
IF @SportID=251 -- RNG Casino
		BEGIN 
				IF EXISTS (SELECT TOP 1 1 FROM dbo.CustInfo WITH (NOLOCK) WHERE custid=@custid )
					BEGIN 
						UPDATE dbo.CustInfo WITH (ROWLOCK,UPDLOCK)
						SET 	disableCasino=@Status 
						WHERE custid=@custid
						
						  SELECT @ErrMsg = @UserName + ': '+
								CASE @Language 
									WHEN 'E' THEN 'Update process is successful !'
									WHEN 'CS' THEN N'??????? !'
									WHEN 'CT' THEN N'??????? !'
									WHEN 'TH' THEN N'????????????????????????????????????????????!'
									WHEN 'J' THEN N'????????????'
									WHEN 'KO' THEN N'????? ??????.'
									ELSE N'Update process is successful !'
								END
								RETURN	
					END
			 ELSE 
				BEGIN 
					 SELECT @ErrMsg = @UserName + ': '+
								CASE @Language 
									WHEN 'E' THEN 'This customer has never played Live Casino !'
									WHEN 'CS' THEN N'??????? !'
									WHEN 'CT' THEN N'??????? !'
									WHEN 'TH' THEN N'????????????????????????????????????????????!'
									WHEN 'J' THEN N'????????????'
									WHEN 'KO' THEN N'????? ??????.'
									ELSE N'This customer has never played Live Casino!'
								END, @ErrCode = 115
								RETURN	
				END	
		END

	DECLARE @TrackingValue VARCHAR(5000)
	DECLARE @startRun DATETIME,
				@endRun DATETIME,
				@duration INT
	
	SELECT @TrackingValue ='<Lrf_CustomerUpdCasinoStatus custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
	'Sporttype="'+ COALESCE(CAST(@SportID as VARCHAR(50)),SPACE(1)) + '" ' +
	'Status="'+ COALESCE(CAST(@Status as VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
	'Language="'+ COALESCE(CAST(@Language as VARCHAR(2)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1)) + '" />'
	

	SET @endRun = GETDATE()
	SET @duration  = datediff (millisecond,@startRun,@endRun)

	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
		@UserID = @UserID,
		@CustID = @CustID,
		@ActionID = 2014,
		@TrackingValue = @TrackingValue,
		@TrackingValue2 = NULL,
		@duration = @duration
END

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdCasinoStatus] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdCasinoStatus] TO vnteam

