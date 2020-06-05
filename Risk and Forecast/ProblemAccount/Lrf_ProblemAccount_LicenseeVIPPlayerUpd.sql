/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_ProblemAccount_LicenseeVipPlayerUpd
	@AgentList VARCHAR(MAX),
	@Username VARCHAR(MAX),
	@IsVip	BIT,
	@UserID INT,
	@IP	VARCHAR(15) = '',
	@Username2 VARCHAR(MAX) = ''
AS
	/*
		Created: 20200213@Johnson
		Task: Problem Account - Licensee VIP player 
		DB: DBCUST/CUSTDB
		
		Revisions:
			- 20200213@Johnson: initial sp [redmine:#128077]
			- 20200417@Elodie: Unremove VIP if void abnormal [Redmine: #132736]
			- 20200605@Eden:LAP - Upload VIP list by ExternalID #135410

		Paramter's Explanations:	
			- @result:
				ErrCode =
						100: invalid SystemID
						101: dont change status SystemID
						102: dont set vip status coz of void tickets
						0: total accounts update successfully 
						1000: Invalid parameter.
						103: invalid ExternalID
						104: dont change status ExternalID
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
	SET @startRun = GETDATE()
	
	CREATE TABLE #tblCust (custid INT, 
							username VARCHAR(50), 
							roleid TINYINT, 
							isVip BIT, 						
							isLog BIT DEFAULT 0, 
							isUpdate BIT DEFAULT 0,
							MaxBet MONEY,
							MaxPerEvent MONEY,
							username2 VARCHAR(50)	
							)
	CREATE TABLE #TempAg (custid INT)
	
	DECLARE @Result TABLE(ErrCode INT,cnt INT, ErrMsg VARCHAR(MAX))
	DECLARE @DocHandler INT
			,@custList VARCHAR(MAX)
			,@ErrMsg VARCHAR(MAX)
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
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	
	INSERT INTO #tblCust(username)
	SELECT DISTINCT val
	FROM dbo.strSplit(@username,',')
	WHERE val <> '' 

	INSERT INTO #tblCust(username2)
	SELECT DISTINCT val
	FROM dbo.strSplit(@username2,',')
	WHERE val <> ''
	
	SELECT custid,roleid, username,
		SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2
	INTO #tempUser
	FROM customer ci WITH(NOLOCK)
	WHERE recommend IN (SELECT custid FROM #TempAg)
		AND roleid = 1	
			
	UPDATE t
	SET t.custid = c.custid,
		t.roleid = c.roleid
	FROM #tblCust t
		INNER JOIN #tempUser c 
			ON t.username = c.username 

	UPDATE t
	SET t.custid = c.custid,
		t.roleid = c.roleid
	FROM #tblCust t
		INNER JOIN #tempUser c 
			ON t.username2 = c.username2 

	IF EXISTS (SELECT 1 FROM #tblCust WHERE custid IS NULL)
	BEGIN	
		SELECT @ErrMsg = ''
		
		SELECT @ErrMsg = @ErrMsg + username + ','
		FROM #tblCust
		WHERE custid IS NULL
			AND username IS NOT NULL
		
		SELECT @cnt = @@ROWCOUNT
		
		SELECT @ErrMsg = REVERSE(SUBSTRING(REVERSE(@ErrMsg),2,LEN(@ErrMsg)))
		
		--invalid accounts by Username
		IF @cnt > 0
			INSERT INTO @Result(ErrCode,Cnt,ErrMsg)
			SELECT 100,@cnt,@ErrMsg

		SELECT @ErrMsg = ''
		
		SELECT @ErrMsg = @ErrMsg + username2 + ','
		FROM #tblCust
		WHERE custid IS NULL
			AND username2 IS NOT NULL
		
		SELECT @cnt = @@ROWCOUNT
		
		SELECT @ErrMsg = REVERSE(SUBSTRING(REVERSE(@ErrMsg),2,LEN(@ErrMsg)))
		
		--invalid accounts by Username2
		IF @cnt > 0
			INSERT INTO @Result(ErrCode,Cnt,ErrMsg)
			SELECT 103,@cnt,@ErrMsg
	END
	
	UPDATE t
	SET t.isVip = CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END 
	FROM #tblCust t
		LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t.custid = d.custid
	
	IF EXISTS (SELECT 1 FROM #tblCust WHERE isVip = @isVip AND custid IS NOT NULL)
	BEGIN	
		--By UserName
		SELECT @ErrMsg = ''
		
		SELECT @ErrMsg = @ErrMsg + username + ','
		FROM #tblCust
		WHERE isVip = @isVip
			AND custid IS NOT NULL	
			AND username IS NOT NULL	
		
		SELECT @cnt = @@ROWCOUNT
		
		SELECT @ErrMsg = REVERSE(SUBSTRING(REVERSE(@ErrMsg),2,LEN(@ErrMsg)))
		
		--no change vip status
		IF @cnt > 0
			INSERT INTO @Result(ErrCode,Cnt,ErrMsg)
			SELECT 101,@cnt,@ErrMsg

		--By UserName2
		SELECT @ErrMsg = ''
		
		SELECT @ErrMsg = @ErrMsg + username2 + ','
		FROM #tblCust
		WHERE isVip = @isVip
			AND custid IS NOT NULL		
			AND username2 IS NOT NULL
		
		SELECT @cnt = @@ROWCOUNT
		
		SELECT @ErrMsg = REVERSE(SUBSTRING(REVERSE(@ErrMsg),2,LEN(@ErrMsg)))
		
		--no change vip status
		IF @cnt > 0 
			INSERT INTO @Result(ErrCode,Cnt,ErrMsg)
			SELECT 104,@cnt,@ErrMsg
	END
	
	--> Distinct custid to update and write log
	SELECT DISTINCT custid,t.isLog,t.isUpdate,t.isVip,t.MaxBet,t.MaxPerEvent,t.roleid
	INTO #tblCust2
	FROM #tblCust t

	UPDATE t
	SET t.MaxBet = p.MaxBet,
		t.MaxPerEvent = p.MaxPerEvent
	FROM #tblCust2 t
		INNER JOIN ProblemAccount p WITH(NOLOCK) ON t.custid = p.custid
	
	IF NOT EXISTS(SELECT 1 FROM #tblCust2 
				WHERE isVip <> @isVip 
					AND custid IS NOT NULL)
	BEGIN				
		SELECT * FROM @Result
		
		RETURN;
	END
	
	WHILE(1=1)
	BEGIN
		SELECT @custList = ''
		
		UPDATE TOP (5000) t
		SET @custList = @custList + CAST(custid AS VARCHAR(10)) + ',',
			isUpdate = 1
		FROM #tblCust2 t
		WHERE isVip <> @isVip
			AND isUpdate = 0
			AND custid IS NOT NULL
		
		SELECT @cnt = @@ROWCOUNT
				
		EXEC Acc_CustomerInfo_Execrep_03 
			@CustList = @custList,
			@UserID = @UserID,
			@isVip = @isVip,
			@mode = 'VIPStatus'

		IF @cnt < 5000
			BREAK;
	END
	
	--total customer update successfully
	INSERT INTO @Result(ErrCode,Cnt, ErrMsg)
	SELECT 0, count(1),''
	FROM #tblCust2
	WHERE isUpdate = 1
	
	--write log
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

	-- Write log
	DECLARE @LogData VARCHAR(500),
			@LogData_Old VARCHAR(500),
			@MaxBet MONEY,
			@MaxPerEvent MONEY,
			@custid INT
	
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) t
		SET isLog = 1,
			@custid = custid,
			@MaxBet = MaxBet,
			@MaxPerEvent = MaxPerEvent
		FROM #tblCust2 t
		WHERE isLog = 0
			AND isUpdate = 1
		
		IF @@ROWCOUNT = 0
			BREAK;

		SELECT  @LogData = '<R'							
							+ ' IsVip="' + COALESCE(CAST(@IsVip AS VARCHAR(10)), SPACE(1)) + '"'
							+ ' MB="' + CASE WHEN @isVip = 0 THEN COALESCE(dbo.f_FomatNumber(CAST(@MaxBet AS VARCHAR(10))), SPACE(1)) ELSE '' END + '"'
							+ ' MPM="' + CASE WHEN @isVip = 0 THEN COALESCE(dbo.f_FomatNumber(CAST(@MaxPerEvent AS VARCHAR(10))), SPACE(1)) ELSE '' END + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'	
							
		SELECT  @LogData_old = '<R'
								+ ' IsVip="' + COALESCE(CAST(CASE WHEN @IsVip = 1 THEN 0 ELSE 1 END AS VARCHAR(10)), SPACE(1)) + '"'
								+ ' MB="' + COALESCE(dbo.f_FomatNumber(CAST(@MaxBet AS VARCHAR(10))), SPACE(1)) + '"'
								+ ' MPM="' + COALESCE(dbo.f_FomatNumber(CAST(@MaxPerEvent AS VARCHAR(10))), SPACE(1)) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'
							
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
				@UserId				= @UserId,
				@CustID				= @custid,		
				@ActionId			= 31625,
				@TrackingValue		= @LogData,
				@TrackingValue2		= @LogData_Old,
				@Duration			= @Duration
	END		
	
	SELECT * FROM @Result
	
END	
GO