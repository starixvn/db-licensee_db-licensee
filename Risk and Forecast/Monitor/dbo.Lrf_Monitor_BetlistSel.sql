ALTER PROCEDURE [dbo].[Lrf_Monitor_BetlistSel]
	@LicenseeID INT,
	@UserID		INT,
	@bettype VARCHAR(50) = NULL,
	@LicenseeType VARCHAR(100) = NULL,
	@Currency VARCHAR(200) = NULL ,
	@SpecialLevel VARCHAR(200) = NULL,
	@transid BIGINT = 0,
	@LimitRowCount INT = 10, 
	@debug bit = 0
AS

BEGIN
	/*	
		Created	: Henry
		Task: Monitor lastest bets list( all bettypes and all sports)
		Date: 2011-10-11
		DB: DB052.BODB02
		Original: 
		Revision:
		- 20111122@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
		- 20111212@Jim: Edit condition bettype <=19000
		- 20111222@Henry: Get the list of Special Level > 0 only
		- 20111229@Jim: remove function :f_ShowOddsByBettype,f_GetOddsByBettype,Lrf_f_GetChoice
		- 20120117@Henry: Enhance performance by using dynamic query 
		- 20120227@Henry: put index hint and get only running ticket
		- 20120309@Don: force index query hint and avoid subquery 
		- 20120827@Henry: Add Actual_stake
		- 20120906@Jim : add virtual sport bettype
		- 20130219@Daniel : remove support virtual sport 
		- 20130402@Jim: re-filter bettype condition 
		-20130618@Jim:  Restrict permission of Licensee Users by currency
		Parameter's Explanation:
			- @bettypes: 
				+ HDP: 1,7
				+ Others: NOT IN 1,3,7,8
				+ OU: 3,8
				+ ALL: <=19000
			- @transid: lastest transid 
			- @LimitRowCount: max record return (10,20,30)
	*/ 

	DECLARE @SQL VARCHAR(8000)
	DECLARE @ORDERBY VARCHAR(1000)
	SELECT @SQL='SET NOCOUNT ON '

	DECLARE @isDisable bit			
	SET @isDisable = 1
	IF @isDisable = 0
	BEGIN
		RAISERROR ('This function is temporarily unavailable!', 16,1);
		RETURN
	END

	SET @bettype = LTRIM(RTRIM(ISNULL(@bettype,'ALL')))
	SET @Currency = LTRIM(RTRIM(ISNULL(@Currency,'0')))
	SET @LicenseeType = LTRIM(RTRIM(ISNULL(@LicenseeType,'ALL')))
	SET @SpecialLevel = LTRIM(RTRIM(ISNULL(@SpecialLevel,'')))

	IF @bettype = ''
		SET @bettype = 'ALL'

	IF 	@LicenseeType = ''
		SET @LicenseeType = 'ALL'
		
	IF 	@Currency = ''
		SET @Currency = '0'

	SELECT @SQL = @SQL + 'DECLARE @TempAg AS TABLE ( Recommend INT PRIMARY KEY, currency int )'+CHAR(13)+
				'INSERT INTO @TempAg'+CHAR(13)+
				'SELECT  lc.CustID, currency'+CHAR(13)+	
				'FROM    bodb_Licensee.dbo.LicenseeCust lc WITH  ( NOLOCK )'+CHAR(13)+
							'INNER JOIN bodb_licensee.dbo.CurrencyUser c WITH (NOLOCK) ON  lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID'+char(13)+
				'WHERE   lc.LicenseeID = '+convert(varchar(10),@LicenseeID)+CHAR(13)+
					'AND c.usrID='+convert(VARCHAR(20),@userID)+char(13)+
					--CASE WHEN @Currency <> '0' THEN ' AND currency IN (SELECT convert(int,val) FROM dbo.strSplit('''+@Currency+''','',''))' ELSE '' END + char(13)+
					CASE WHEN @Currency <> '0' THEN ' AND lc.currency IN ('+@Currency+')' ELSE '' END + char(13)+
					CASE WHEN @LicenseeType <> 'ALL' THEN ' AND [Description] = ''' + @LicenseeType + ''' ' ELSE '' END + char(13)+
					'AND lc.RoleId = 2'+CHAR(13)+
					'AND c.IsActive=1'+CHAR(13)

    SELECT @SQL = @SQL + 
        CASE 
	        WHEN @SpecialLevel <> '' AND (CHARINDEX('0', @SpecialLevel)>1 OR CHARINDEX('0', @SpecialLevel)=0) THEN 
	            'DECLARE @Level AS TABLE ( custid INT PRIMARY KEY, username2 varchar(50), SpecialLevel int)'+CHAR(13)+ 
				'INSERT INTO @Level'+CHAR(13)+
				'SELECT  custid, username2, SpecialLevel'+CHAR(13)+	
				'FROM    bodb_Licensee.dbo.LicenseeCustinfo WITH (NOLOCK)'+CHAR(13)+
				--'WHERE   SpecialLevel IN (SELECT val FROM dbo.strSplit('''+@SpecialLevel+''','',''))'+CHAR(13)
				'WHERE   SpecialLevel IN ('+@SpecialLevel+')'+CHAR(13)
	        ELSE ''
        END

	SELECT @SQL = @SQL + 'SELECT TOP ('+CONVERT(VARCHAR(10),@LimitRowCount)+')'+CHAR(13)+
							'0 AS sporttype,'+CHAR(13)+
							'b.matchid,'+CHAR(13)+
							'0 AS leagueid,'+CHAR(13)+
							'b.Username,'+CHAR(13)+
							'SUBSTRING(lc.username2, CHARINDEX(''$'', lc.username2) + 1,LEN(lc.username2) - CHARINDEX(''$'',lc.username2)) AS nickname,'+CHAR(13)+
							'b.bettype,'+CHAR(13)+
							'b.transid,'+CHAR(13)+
							'b.refno,'+CHAR(13)+
							'b.transdate,'+char(13)+				
							''''' AS matchcode,'+CHAR(13)+
							'0 AS homeid,'+CHAR(13)+
							'0 AS awayid,'+CHAR(13)+
							''''' AS race,'+CHAR(13)+
							'b.betid,'+CHAR(13)+
							'b.livehomescore,'+CHAR(13)+
							'b.liveawayscore,'+CHAR(13)+
							'CONVERT(INT,b.liveindicator) AS LiveIndicator,'+CHAR(13)+
							'b.hdp1,'+CHAR(13)+
							'b.hdp2,'+CHAR(13)+
							'b.odds,'+CHAR(13)+
							'b.actual_stake,'+CHAR(13)+
							'b.stake,'+CHAR(13)+
							'''running'' as status,'+CHAR(13)+
							'b.betteam,'+CHAR(13)+				
							'CONVERT(BIT,0) AS isNeutral,'+CHAR(13)+ 		
							'b.OddsType,'+CHAR(13)+
							't.currency as currencyid,'+CHAR(13)+
							''''' as currencyname,'+CHAR(13)+
							'lc.SpecialLevel'+CHAR(13)+
						'FROM dbo.bettrans b WITH(NOLOCK,INDEX(IX_recommend_transid))'+CHAR(13)+
							'INNER JOIN @TempAg t ON b.recommend=t.recommend'+CHAR(13)+
							CASE 
								WHEN @SpecialLevel <> '' AND (CHARINDEX('0', @SpecialLevel)>1 OR CHARINDEX('0', @SpecialLevel)=0)
									THEN 'INNER JOIN  @Level lc ON b.custid = lc.custid'
								ELSE 
									'INNER JOIN  bodb_Licensee.dbo.LicenseeCustinfo lc WITH (NOLOCK) ON b.custid = lc.custid'  
							END +CHAR(13)+
						'WHERE '+CHAR(13)+
							'(b.bettype <31 OR b.bettype BETWEEN 121 AND 999)'+char(13)+
							'AND b.transid > '+convert(varchar(10),@transid)+CHAR(13)+
							'AND b.statusID = 0'+CHAR(13)+
							CASE WHEN @SpecialLevel <> '' THEN 
								CASE WHEN (CHARINDEX('0', @SpecialLevel)>1 OR CHARINDEX('0', @SpecialLevel)=0) THEN ''
									ELSE ' AND lc.SpecialLevel IN ('+@SpecialLevel+')'  END
								ELSE '' END  +CHAR(13) +
							CASE 
								WHEN @bettype = 'HDP' THEN ' AND b.bettype IN (1,7)'
								WHEN @bettype = 'OU' THEN ' AND b.bettype IN (3,8)' 
								WHEN @bettype = 'Others' THEN ' AND b.bettype NOT IN (1,3,7,8)' 
								ELSE '' END +CHAR(13) +
						'ORDER BY b.transid DESC'+CHAR(13)	
			
		
	IF (@debug = 1) PRINT @sql
	ELSE EXEC(@sql)
END

GO
GRANT EXECUTE ON [dbo].[Lrf_Monitor_BetlistSel] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Monitor_BetlistSel] TO [vnteam] AS [dbo]