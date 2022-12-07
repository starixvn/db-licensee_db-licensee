/*<info serverAlias="DBCUST-bodb_CustomerLog,DBLOG-bodb_CustomerLog" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="1"></info>*/

ALTER PROCEDURE [dbo].[Lrf_WriteLog_UserLog_UserControl_Multiple]
	@LogData NVARCHAR(MAX),	
	@TypeID tinyint=0,
	@ActionID int=0,
	@Duration int = 0,
	@UserID	INT 
AS
/*
	Created: 20221109@Johnson
	Task : Write multiple log for LAP when update settings
	DB: DBCUST/bodb_CustomerLog, DBLOG/bodb_CustomerLog

	Revisions :
		- 20221109@Johnson: initial sp [redmine:#179961]
		- 20221110@Tacy: LAP - Support Danger Level report (Add ActionID 1191-1196) [RedmineID: #179078]

	Parameter Explanation:
		@ActionID = 5567	--Deactive VIP
				  = 1191	--Auto Update Saba Soccer Danger Level
				  = 1192	--Auto Update Saba Basketball Danger Level
				  = 1193	--Manual Update Saba Soccer Danger Level
				  = 1194	--Manual Update Saba Basketball Danger Level
				  = 1195	--Manual Update - Unchanged Saba Soccer Danger Level
				  = 1196	--Manual Update - Unchanged Saba Basketball Danger Level

		-@ActionID = 5562
			@LogData = '<Root>
							<r id="1" log="LAP - 12Bet - 1 - 5 - Success - OFF - ON" />
							<r id="2" log="LAP - 12Bet - 1 - 5 - Success - OFF - ON" />
						</Root>'
			id: custid, log: log update		

		-@ActionID = 1191,1192
			@Log = '<Root>
					<r id="1" sport="0" newlevel="10" oldlevel="11" wl="1000" IsPA="1">
					<r id="2" sport="1" newlevel="10" oldlevel="11" wl="1000" IsPA="1">
				</Root>
				'
		-@ActionID = 1193~1196
			@Log = '<Root>
					<r id="1" sport="0" newflag="1" oldflag="0" newlevel="10" oldlevel="5" />
					<r id="2" sport="1" newflag="1" oldflag="0" newlevel="10" oldlevel="15" />
				</Root>
				'		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xml XML = CAST (@LogData as XML)
	
	IF @ActionID = 5567 --Deactive VIP
	BEGIN
		CREATE TABLE #tblLogVIP (custid INT PRIMARY KEY, log NVARCHAR(MAX))
		
		INSERT INTO #tblLogVIP(custid,log)	
		SELECT t.c.value('@id','INT')	AS custid		
			,t.c.value('@log', 'NVARCHAR(MAX)')	AS log			
		FROM @xml.nodes ('Root/r') t(c)
		OPTION (OPTIMIZE FOR (@xml = NULL))
				
		INSERT INTO  dbo.UserLog_UserControl
			   ([CustID]
			   ,[LogDate]
			   ,[UserID]
			   ,[TypeID]
			   ,[ActionID]
			   ,[Duration]
			   ,[Doing])
		SELECT custid, 
			GETDATE(),
			@UserID,
			@TypeID,
			@ActionID,
			@Duration,
			log
		FROM #tblLogVIP
		
		DROP TABLE #tblLogVIP
	END	
	ELSE
	BEGIN
		
		CREATE TABLE #tblCustLog(
				custid			INT PRIMARY KEY, 
				sport			TINYINT, 
				NewFlag			BIT,
				OldFlag			BIT, 
				NewLevel		TINYINT, 
				OldLevel		TINYINT, 
				Winloss			MONEY, 
				IsUpdatedByPA	BIT)

		IF @ActionID IN (1191, 1192)		--auto update dangerlevel
		BEGIN
			INSERT INTO #tblCustLog(custid,sport,newlevel,oldlevel,Winloss,IsUpdatedByPA)
			SELECT t.c.value('@id[1]','int'),
					t.c.value('@sport[1]','tinyint'),
					t.c.value('@newlevel[1]','tinyint'),
					t.c.value('@oldlevel[1]','tinyint'),
					CASE WHEN ISNUMERIC(t.c.value('@wl[1]','varchar(10)'))=0 THEN NULL ELSE t.c.value('@wl[1]','money') END,
					t.c.value('@IsPA[1]','bit')
			FROM @xml.nodes('Root/r')as t(c)
			OPTION (OPTIMIZE FOR (@xml = NULL))

			;WITH Tmp AS (
			SELECT custid,
					(SELECT 
						CASE WHEN sport = 0 THEN 'Soccer' WHEN sport= 1 THEN 'Basketball' END as '@SportType',
						NewLevel			as '@NewLevel',
						OldLevel			as '@OldLevel',
						ISNULL(Winloss,'')	as '@Winloss',
						IsUpdatedByPA		as '@IsUpdatedByPA'
					FROM #tblCustLog t1
					WHERE t1.custid = t.custid
					FOR XML PATH('R')
					) as Logdata
			FROM #tblCustLog t
			)
			INSERT INTO  dbo.UserLog_UserControl
				([CustID]
				,[LogDate]
				,[UserID]
				,[TypeID]
				,[ActionID]
				,[Duration]
				,[Doing])
			SELECT custid, 
				GETDATE(),
				@UserID,
				@TypeID,
				@ActionID,
				@Duration,
				Logdata
			FROM Tmp
		
			DROP TABLE #tblCustLog
		END
		ELSE IF @ActionID IN (1193,1194,1195,1196)	--manual update  dangerlevel
		BEGIN
			INSERT INTO #tblCustLog(custid,sport,newflag,oldflag,newlevel,oldlevel)
			SELECT t.c.value('@id[1]','int'),
				t.c.value('@sport[1]','tinyint'),
				t.c.value('@newflag[1]','bit'),
				t.c.value('@oldflag[1]','bit'),
				t.c.value('@newlevel[1]','tinyint'),
				t.c.value('@oldlevel[1]','tinyint')
			FROM @xml.nodes('Root/r')as t(c)
			OPTION (OPTIMIZE FOR (@xml = NULL))
		
			;WITH Tmp AS (
			SELECT custid,
				(SELECT 
					CASE WHEN sport = 0 THEN 'Soccer' WHEN sport= 1 THEN 'Basketball' END as '@SportType',
					NewLevel as '@DangerLevel',
					NewFlag as '@ManualDangerLevel'
				FROM #tblCustLog t1
				WHERE t1.custid = t.custid
				FOR XML PATH('New')
				) as LogNew,
				(SELECT 
					CASE WHEN sport = 0 THEN 'Soccer' WHEN sport= 1 THEN 'Basketball' END as '@SportType',
					OldLevel as '@DangerLevel',
					OldFlag as '@ManualDangerLevel'
				FROM #tblCustLog t2
				WHERE t2.custid = t.custid
				FOR XML PATH('Old')
				) as LogOld
			FROM #tblCustLog t
			)
			INSERT INTO  dbo.UserLog_UserControl
				([CustID]
				,[LogDate]
				,[UserID]
				,[TypeID]
				,[ActionID]
				,[Duration]
				,[Doing])
			SELECT custid, 
				GETDATE(),
				@UserID,
				@TypeID,
				@ActionID,
				@Duration,
				'<ROOT>' + LogNew + LogOld + '</ROOT>'
			FROM Tmp
		
			DROP TABLE #tblCustLog
		END
	END
END			
GO