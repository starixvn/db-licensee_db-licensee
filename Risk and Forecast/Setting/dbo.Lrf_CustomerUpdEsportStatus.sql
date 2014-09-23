
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdEsportStatus]
	@CustId			  INT
	,@UserId		  INT = 0
	,@DisableEsports  BIT=0
	,@Langkey         VARCHAR(2) = 'en-US'
	,@IP              VARCHAR(15)= ''
	,@ErrCode         INT = 0 OUTPUT
	,@ErrMsg          NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20140821@Jim
Task : LRF - Implement Esports Setting (Comm/Bet Setting/ Enable-Disable Game) -- redmineID:#20744
DB: DBTXN.CustDB

Revisions:
  
Param's Explanation:
	? @CustID: member ID
*/

	BEGIN
		SET NOCOUNT ON 
		DECLARE @startRun  DATETIME
				,@endRun   DATETIME
				,@duration INT	
				,@Old_DisableEsports BIT
				,@LogSPData VARCHAR(8000)
				,@LogSPData2 VARCHAR(8000)
				
		SET @startRun = GETDATE()
		EXEC DBEXT.bodb02.dbo.[Lrf_CustomerSelCheckEnable]	
			@custid   = @CustId	 
			,@Langkey = @Langkey 
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg  = @ErrMsg  OUTPUT
		IF @ErrCode<>0
			BEGIN 
				RETURN
			END
		SELECT 	@Old_DisableEsports = DisableEsports
		FROM dbo.Custinfo WITH (NOLOCK)
		WHERE CustID = @CustID
		
		IF @Old_DisableEsports = @DisableEsports
			BEGIN 
				RETURN
			END
		ELSE 
			BEGIN 
				UPDATE dbo.CustInfo WITH (ROWLOCK,UPDLOCK)
				SET DisableEsports = @DisableEsports
				WHERE CustID = @CustID
				---- write log
				SELECT @LogSPData = '<Lrf_CustomerUpdEsportStatus'
								  + 'CustId="'+ COALESCE(CAST(@custid AS VARCHAR(50)), SPACE(1)) + '" '
								  + 'DisableEsports="'+ COALESCE(CAST(@DisableEsports AS VARCHAR(2)), SPACE(1)) + '" '
								  + 'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)), SPACE(1)) + '" '	
								  + 'Language="'+ COALESCE(CAST(@Langkey AS VARCHAR(2)), SPACE(1)) + '" '
								  + 'IP="'+ COALESCE(CAST(@IP AS VARCHAR(15)), SPACE(1)) + '" '
								  + 'ErrCode="'+ COALESCE(CAST(@ErrCode AS VARCHAR(50)), SPACE(1)) + '" '
								  + 'ErrMsg="'+ COALESCE(CAST(@ErrMsg AS VARCHAR(4000)), SPACE(1)) + '" />'
				SELECT @LogSPData2 = '<Lrf_CustomerUpdEsportStatus'
								   + 'CustId="'+ COALESCE(CAST(@custid AS VARCHAR(50)), SPACE(1)) + '" '
								   + 'DisableEsports="'+ COALESCE(CAST(@Old_DisableEsports AS VARCHAR(2)), SPACE(1)) + '" '
								   + 'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)), SPACE(1)) + '" '	
								   + 'Language="'+ COALESCE(CAST(@Langkey AS VARCHAR(2)), SPACE(1)) + '" '
								   + 'IP="'+ COALESCE(CAST(@IP AS VARCHAR(15)), SPACE(1)) + '" '
								   + 'ErrCode="'+ COALESCE(CAST(@ErrCode AS VARCHAR(50)), SPACE(1)) + '" '
								   + 'ErrMsg="'+ COALESCE(CAST(@ErrMsg AS VARCHAR(4000)), SPACE(1)) + '" />'
								  
				SET @endRun = GETDATE()
				SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)   
				BEGIN TRY
					EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
							@UserID = @UserID
							,@CustID = @CustID
							,@ActionID = 2042
							,@TrackingValue = @LogSPData
							,@TrackingValue2 = @LogSPData2
							,@duration = @duration
				END TRY
				BEGIN CATCH
					EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
						@UserID = @UserID
						,@CustID = @CustID
						,@ActionID = 2042
						,@TrackingValue = @LogSPData
						,@TrackingValue2 = @LogSPData2
						,@duration = @duration
				END CATCH	
					
			END
	END	
	
GO 
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdEsportStatus] TO [bodbLicenseeNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdEsportStatus] TO [vnteam]