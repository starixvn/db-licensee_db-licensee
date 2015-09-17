USE [bodb_licensee]
GO

ALTER FUNCTION [dbo].[LA_f_GetChargeInfoWithTrialTime] (@PartyIDs VARCHAR(1000)
	, @FromDate DATETIME
	, @ToDate DATETIME
	, @ProductCodes VARCHAR(1000)
	, @System VARCHAR(10) = 'OA'
	, @ExcludeTest BIT)
RETURNS @tbChargeInfo TABLE (ChargeId INT
	, PartyId INT
	, LicenseeId INT
	, IsDeposit INT
	, AffectedDate SMALLDATETIME
	, ProductId INT
	, DI_Rate MONEY
	, OW_Rate MONEY
	, PNR_Rate MONEY
	, FromDate SMALLDATETIME
	, ToDate SMALLDATETIME)
AS
/*  Created: 20150618@Patrick
    Task : Get charge information for trial time but have charge rate for summary data to bettrans only
    DB: DB052/bodb_Licensee  
    Param's Explanation:
    select * FROM dbo.LA_f_GetChargeInfoWithTrialTime ('14','2016-06-01','2016-06-30','GD','OA', 0)
*/

BEGIN     
    INSERT INTO @tbChargeInfo (ChargeID , PartyID, LicenseeID, isDeposit, AffectedDate, ProductID, DI_Rate, OW_Rate, PNR_Rate, Fromdate, Todate)
	SELECT DISTINCT DI.ChargeID 
		, p.PartyID
		, CASE 
		 	WHEN ISNULL(pd.IsDeposit, 0) = 1
		 		THEN p.OldRefID
		 	ELSE lb.LabelID
		 	END AS LicenseeID
		, pd.IsDeposit
		, @FromDate AS AffectedDate
		, DI.ProductID
		, CASE WHEN DI.Rate = 0 THEN ISNULL(OW.Rate,0) ELSE DI.Rate END AS DI_Rate	
		, 0	 AS OW_Rate  -- not use now
		, 0	 AS PNR_Rate -- not use now
		, CASE 
		 	WHEN @FromDate <= DI.FromDate 
		 		THEN DI.FromDate
		 	ELSE @FromDate
		 	END
		, CASE 
			WHEN @ToDate >= DI.ToDate 
				THEN DI.ToDate
			ELSE @ToDate
			END
	FROM dbo.OAS_Party p WITH (NOLOCK)	
		INNER JOIN dbo.OAS_ChargeInfo DI WITH (NOLOCK) ON DI.FromParty = p.PartyID	AND DI.ChargeType = 1 AND p.PartyType = 1
		LEFT JOIN dbo.OAS_ChargeInfo OW WITH (NOLOCK) ON DI.ParentChargeID = OW.ChargeID
		LEFT JOIN dbo.OAS_PartyDetail pd WITH (NOLOCK) ON pd.PartyID = p.PartyID
		LEFT JOIN dbo.labels lb(NOLOCK) ON p.OldRefID = lb.LicenseeID
	WHERE p.PartyID IN (SELECT VAL FROM strSplit(@PartyIDs, ','))		
		AND DI.FromDate IS NULL
		AND DI.ProductID IN (SELECT CASE WHEN s.val = 'SB' THEN 0 ELSE p3.Productid	END
								FROM bodb02.dbo.strSplit(@ProductCodes, ',') s
								LEFT JOIN dbo.Product3rd p3 WITH (NOLOCK) ON s.val = p3.ProductPrefix
							)
	ORDER BY p.PartyID, Di.ProductID

	RETURN
END
GO

GRANT SELECT ON [dbo].[LA_f_GetChargeInfoWithTrialTime] TO [bodbAdminNet] AS [dbo]
GO

GRANT SELECT ON [dbo].[LA_f_GetChargeInfoWithTrialTime] TO [vnteam] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[LA_f_GetChargeInfoWithTrialTime] TO [vnteam] AS [dbo]
GO


