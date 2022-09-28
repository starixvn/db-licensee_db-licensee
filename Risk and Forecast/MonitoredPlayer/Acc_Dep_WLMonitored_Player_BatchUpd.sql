/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Acc_Dep_WLMonitored_Player_BatchUpd
	 @AgentList VARCHAR(MAX)
	,@Sporttype SMALLINT = 0
	,@XML VARCHAR(MAX) = ''
	,@UserId INT = 0
	,@IP VARCHAR(20) = ''
AS  
/*  
	Created:	20220523@Eden
	Task:		Insert/Update Player threshold by batch upload
	DB:			DBCUST-CUSTDB
	Original:	
  
	Revisions:  
	    - 20220523@Eden: LAP - Player Segmentation - Monitored Player [Redmine:#172605]

	Param's Explanation:  	
	- @Result:
			ErrCode =
				1000: Invalid parameter.
				100: Invalid System ID
				101: Invalid External ID
				103: Invalid Daily Winning Threshold
				104: Invalid account
				0: Update successfully 

	EXEC Acc_Dep_WLMonitored_Player_BatchUpd 
		 @AgentList='<ROOT><Agent AgentId="3233923" Currency="2"/></ROOT>'
		,@XML = '<ROOT>
			<CustList RID="1" U1="" U2="amytest11" WT="2000" />
			<CustList RID="2" U1="" U2="william2232018a" WT="1000" />
			<CustList RID="3" U1=""	U2="" WT="8000" />
			<CustList RID="4" U1="" U2="Bobo88RM05603sss" WT="5000" />
			<CustList RID="5" U1=""	U2="Bobo88RM05603a" WT="5000" />
			<CustList RID="6" U1=""	U2="Bobo88RM05603d" WT="5000" />
			</ROOT>'
		,@Sporttype = 0
		,@UserId = 8
		,@IP = '0.0.0.0'
*/  
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
	DECLARE @ErrCode INT = 0 ,@ErrMsg VARCHAR(500) = ''
	DECLARE @Site varchar(10)

	SET @startRun = GETDATE()
	
	CREATE TABLE #tblCust (
			RID INT,
			custid INT, 
			Input_username VARCHAR(30), 	
			Input_username2 VARCHAR(50),
			WinningThreshold MONEY,
			isProcessed BIT DEFAULT 0,
	)

	CREATE TABLE #TempAg (custid INT)
	
	DECLARE @Result TABLE(ErrCode INT, ErrMsg VARCHAR(MAX), username VARCHAR(30), username2 VARCHAR(50))
	DECLARE @DocHandler INT
			,@custList VARCHAR(MAX)
			,@cnt INT
				
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 1000
			,ErrMsg = N'Invalid parameter.'

		RETURN
	END CATCH;

	--------process user list
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@XML
	
		INSERT INTO #tblCust(RID,Input_username,Input_username2,WinningThreshold)
		SELECT RID
			,NULLIF(U1,'') AS Input_username
			,NULLIF(U2,'') AS Input_username2
			,WT AS WinningThreshold
		FROM OPENXML(@DocHandler, '/ROOT/CustList', 1) WITH (RID INT, U1 VARCHAR(30), U2 VARCHAR(50), WT MONEY) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 1000
			,ErrMsg = N'Invalid parameter.'

		RETURN
	END CATCH;

	IF EXISTS( SELECT TOP 1 1 FROM #tblCust WHERE Input_username IS NOT NULL)
	BEGIN
		IF EXISTS( SELECT TOP 1 1 FROM #tblCust WHERE Input_username2 IS NOT NULL)
		BEGIN
			SELECT ErrCode = 1000
				,ErrMsg = N'Invalid parameter.(SystemID/ExternalID)'

			RETURN
		END
		ELSE
		BEGIN
			UPDATE t
			SET t.custid = ci.custid
			FROM #tblCust t
				INNER JOIN customer ci WITH(NOLOCK)
					ON t.Input_username = ci.username 
				INNER JOIN #TempAg a 
					ON ci.recommend = a.custid
			WHERE ci.roleid = 1

			DELETE t
			OUTPUT 100,'Invalid System ID',deleted.Input_username INTO @Result(ErrCode,ErrMsg, username)
			FROM #tblCust t
			WHERE t.custid IS NULL
		END
	END
	ELSE
	BEGIN
		IF EXISTS( SELECT TOP 1 1 FROM #tblCust WHERE Input_username2 IS NOT NULL)
		BEGIN
			SELECT TOP (1) @Site = ci.Site 
			FROM #TempAg t
				INNER JOIN customer ci WITH(NOLOCK) ON  ci.custid = t.custid

			UPDATE t
			SET t.custid = ci.custid
			FROM #tblCust t
				INNER JOIN customer ci WITH(NOLOCK)
					ON @site +  '$' + t.Input_username2 = ci.username2 
				INNER JOIN #TempAg a 
					ON ci.recommend = a.custid
			WHERE ci.roleid = 1

			DELETE t
			OUTPUT 101,'Invalid External ID',deleted.Input_username2 INTO @Result(ErrCode,ErrMsg, username2)
			FROM #tblCust t
			WHERE custid IS NULL
		END
	END

	IF NOT EXISTS (SELECT 1 FROM #tblCust)
		GOTO RETURN_LB;

	DECLARE @CustID INT
		,@username VARCHAR(30) = ''
		,@username2 VARCHAR(50) = ''
		,@WinningThreshold INT

	WHILE 1 = 1
	BEGIN
		UPDATE TOP(1) t
		SET t.isProcessed = 1,
			@WinningThreshold = t.WinningThreshold,
			@CustID = t.custid,
			@username = t.Input_username,
			@username2 = t.Input_username2
		FROM #tblCust t
		WHERE isProcessed = 0

		IF @@ROWCOUNT = 0
			BREAK

		IF EXISTS ( SELECT 1 FROM Dep_WLMonitored_Player WITH(NOLOCK) WHERE CustID = @CustID AND Sporttype = @Sporttype)
		BEGIN
			EXEC Acc_Dep_WLMonitored_Player_Upd
				 @CustID = @CustID
				,@WinningThreshold = @WinningThreshold
				,@ErrCode = @ErrCode OUT
				,@ErrMsg = @ErrMsg OUT
				,@UserID=@UserId
				,@IP=@IP
				,@IsBatchUpd = 1

			--IF @ErrCode <> 0
			BEGIN
				INSERT INTO @Result(ErrCode,ErrMsg, username, username2)
				SELECT @ErrCode, @ErrMsg, @username, @username2
			END
		END
		ELSE
		BEGIN
			EXEC Acc_Dep_WLMonitored_Player_Ins
				 @CustID = @CustID
				,@WinningThreshold = @WinningThreshold
				,@ErrCode = @ErrCode OUT
				,@ErrMsg = @ErrMsg OUT
				,@UserID=@UserId
				,@IP=@IP

			--IF @ErrCode <> 0
			BEGIN
				INSERT INTO @Result(ErrCode,ErrMsg, username, username2)
				SELECT @ErrCode, @ErrMsg, @username, @username2
			END
		END
		
	END

	RETURN_LB:
	SELECT * FROM @Result
	
	DROP TABLE #tblCust
	DROP TABLE #TempAg
END	
GO