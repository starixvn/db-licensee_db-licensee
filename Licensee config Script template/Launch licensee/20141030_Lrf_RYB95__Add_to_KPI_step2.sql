USE bodb_licensee

GO
/*
	Created: Francis  
	Date: 2014-10-30
    Task : RYB95 - Launch of new licensee
    DB: dblic.bodb_licensee 
	
*/

DECLARE @MaxBopingNo INT = 0

SELECT  @MaxBopingNo = MAX(OrderNo) + 1
FROM KPI_Groups g WITH (NOLOCK) 
INNER JOIN KPI_BranchGroup bg WITH (nolock)
	  ON g.GroupID = bg.GroupID
WHERE BranchID = 2

--Boping Branch (Sportbook)
EXEC KPI_AddNewGroup @GroupName = 'RYB95',
					 @BranchID = 2,
					 @OrderNo = @MaxBopingNo,
					 @IsActive = 1,
					 @ProductID = 0

--Boping_NG Branch
EXEC KPI_AddNewGroup @GroupName = 'RYB95',
					 @BranchID = 11,
					 @ProductID = 2

--Boping_LC Branch
EXEC KPI_AddNewGroup @GroupName = 'RYB95',
					 @BranchID = 16,
					 @ProductID = 4

--Boping_RNG Branch
EXEC KPI_AddNewGroup @GroupName = 'RYB95',
					 @BranchID = 19,
					 @ProductID = 6
