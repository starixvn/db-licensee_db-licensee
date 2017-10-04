ALTER VIEW [dbo].[view_MGCRNG_ProgressiveContribution_Rate]
AS
/*
    Created: 20160422@Francis
    Task: Configure Progressive Contribution Rate for some GameTypes of MGCRNG 
    DB: DB052.bodb_LicenseeReport

    Revisions:
    -20170123@Francis: Revise ResourceID for Mega Moolah Isis/CashSplash 3 Reel/CashSplash 5 Reel/Tunzamunni
	- 20171004@Sophia: Change ContributionRate [Redmine: #84259]
*/

	  SELECT 43	AS ResourceID, 'Fruit Fiesta 5 Reel' AS JackpotGame, 0.03 AS Contribution
UNION ALL SELECT 44	AS ResourceID, 'King CashaLot' AS JackpotGame, 0.04 AS Contribution
UNION ALL SELECT 45	AS ResourceID, 'Major Millions' AS JackpotGame, 0.0747 AS Contribution
UNION ALL SELECT 46	AS ResourceID, 'Mega Moolah' AS JackpotGame, 0.088 AS Contribution
UNION ALL SELECT 47	AS ResourceID, 'Treasure Nile' AS JackpotGame, 0.04 AS Contribution
UNION ALL SELECT 48	AS ResourceID, 'WowPot' AS JackpotGame, 0.03 AS Contribution
UNION ALL SELECT 98 AS ResourceID, 'Mega Moolah Isis' AS JackpotGame, 0.088 AS Contribution
UNION ALL SELECT 99 AS ResourceID, 'CashSplash 3 Reel' AS JackpotGame, 0.03 AS Contribution
UNION ALL SELECT 100 AS ResourceID, 'CashSplash 5 Reel' AS JackpotGame, 0.03 AS Contribution
UNION ALL SELECT 101 AS ResourceID, 'Tunzamunni' AS JackpotGame, 0.04 AS Contribution

GO


 