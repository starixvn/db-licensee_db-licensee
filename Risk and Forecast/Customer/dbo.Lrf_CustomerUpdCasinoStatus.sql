/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,Dot_Member,bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdCasinoStatus]
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
	DB: DBCUST/CUSTDB
	Original: 
	Revisions:
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20190909@Eden: 3rd party products - Remove InActive Products Phase 2 [Redmine: #118699]
    
	Param's Explanation:

*/
BEGIN
	DECLARE @UserName VARCHAR(100)
	SELECT @UserName=UserName
	FROM bodb_licensee.dbo.Users WITH (NOLOCK)
	WHERE UserID=@userID

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
									WHEN 'E' THEN 'This customer has never played RNG Casino !'
									WHEN 'CS' THEN N'??????? !'
									WHEN 'CT' THEN N'??????? !'
									WHEN 'TH' THEN N'????????????????????????????????????????????!'
									WHEN 'J' THEN N'????????????'
									WHEN 'KO' THEN N'????? ??????.'
									ELSE N'This customer has never played RNG Casino !'
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

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserID = @UserID,
		@CustID = @CustID,
		@ActionID = 2014,
		@TrackingValue = @TrackingValue,
		@TrackingValue2 = NULL,
		@duration = @duration
END

GO