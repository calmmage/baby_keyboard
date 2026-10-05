import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default async function ErrorPage({
  searchParams,
}: {
  searchParams: Promise<{ error: string }>;
}) {
  const params = await searchParams;

  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-sm">
        <Card>
          <CardHeader>
            <CardTitle className="text-2xl">
              Sorry, something went wrong
            </CardTitle>
          </CardHeader>
          <CardContent>
            {params?.error ? (
              <p className="text-sm text-muted-foreground">
                Error: {params.error}
              </p>
            ) : (
              <p className="text-sm text-muted-foreground">
                An unexpected error occurred.
              </p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
