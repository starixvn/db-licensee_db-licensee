USE bodb_licensee
GO

/*
	Created: 20170901@Harper
	Support: #82524: Heaven - Launch new licensee

	Licensee Name: Heaven   
	Licensee Type: Boping licensee
	Launch product:
		SB: 15%
			Min Fee: 5000 EUR
			Waive: 3 months.
		VS: 15%
		NG: 15%		
		BA

	Launch date: 31-Aug-17
	
	Enable on:
		NAP
		LA
		LRF
		KPI
*/

DECLARE @MaxBopingNo INT = 0

SELECT @MaxBopingNo = MAX(OrderNo) + 1
FROM KPI_Groups g WITH (NOLOCK) 
	INNER JOIN KPI_BranchGroup bg WITH (NOLOCK) ON g.GroupID = bg.GroupID
WHERE BranchID = 2 -- Boping

--Boping Branch (Sportbook)
exec KPI_AddNewGroup @GroupName = 'Heaven',
					 @BranchID = 2,
					 @OrderNo = @MaxBopingNo,
					 @IsActive = 1,
					 @ProductID = 0

--Boping_NG Branch
exec KPI_AddNewGroup @GroupName = 'Heaven',
					 @BranchID = 11,
					 @ProductID = 2